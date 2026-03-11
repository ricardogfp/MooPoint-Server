const mqtt = require('mqtt');

function serializeError(err) {
  if (!err) return err;
  if (err instanceof Error) {
    return {
      name: err.name,
      message: err.message,
      stack: err.stack,
      code: err.code,
    };
  }
  return err;
}

function randomRequestId(prefix = 'req') {
  return `${prefix}_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

function extractVerticesFromGeojson(geojsonStr) {
  const parsed = JSON.parse(geojsonStr);

  // Supports Feature(Polygon|MultiPolygon), Polygon, MultiPolygon.
  const geom = parsed?.type === 'Feature' ? parsed.geometry : parsed;
  if (!geom) throw new Error('invalid_geojson');

  let ring = null;
  if (geom.type === 'Polygon') {
    ring = geom.coordinates?.[0];
  } else if (geom.type === 'MultiPolygon') {
    ring = geom.coordinates?.[0]?.[0];
  }

  if (!Array.isArray(ring) || ring.length < 3) {
    throw new Error('invalid_geojson');
  }

  // GeoJSON uses [lon, lat]
  return ring
    .filter((p) => Array.isArray(p) && p.length >= 2)
    .map((p) => ({ lat: Number(p[1]), lon: Number(p[0]) }))
    .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lon));
}

function createMqttGeofenceSync({ db, logger }) {
  const url = process.env.MQTT_URL || 'mqtt://127.0.0.1:1883';
  const bootTopic = process.env.MQTT_GATEWAY_BOOT_TOPIC || 'moopoint/cmd/geofence/request';
  const updateTopic = process.env.MQTT_GEOFENCE_UPDATE_TOPIC || 'moopoint/cmd/geofence/update';

  const client = mqtt.connect(url, {
    username: process.env.MQTT_USERNAME || undefined,
    password: process.env.MQTT_PASSWORD || undefined,
  });

  client.on('connect', () => {
    logger.info('MQTT connected', { url, bootTopic, updateTopic });
    client.subscribe(bootTopic, (err) => {
      if (err) logger.error('MQTT subscribe failed', { bootTopic, err: serializeError(err) });
      else logger.info('MQTT subscribed', { bootTopic });
    });
  });

  client.on('reconnect', () => {
    logger.info('MQTT reconnecting', { url });
  });

  client.on('offline', () => {
    logger.error('MQTT offline', { url });
  });

  client.on('close', () => {
    logger.error('MQTT connection closed', { url });
  });

  client.on('error', (err) => {
    logger.error('MQTT error', { err: serializeError(err) });
  });

  async function publishWithAckTimeout(topic, payload, options, meta) {
    const timeoutMs = Math.max(1000, Number(process.env.MQTT_PUBLISH_ACK_TIMEOUT_MS || '3000'));
    const startTime = Date.now();
    const payloadSize = Buffer.byteLength(payload, 'utf8');
    
    return await new Promise((resolve) => {
      let finished = false;
      const t = setTimeout(() => {
        if (finished) return;
        finished = true;
        const duration = Date.now() - startTime;
        logger.error('MQTT publish timed out (no ack/callback)', { 
          timeoutMs, 
          duration,
          payloadSize,
          topic,
          ...meta 
        });
        resolve(false);
      }, timeoutMs);

      client.publish(topic, payload, options, (err) => {
        if (finished) return;
        finished = true;
        clearTimeout(t);
        const duration = Date.now() - startTime;
        
        if (err) {
          logger.error('MQTT publish failed', { 
            duration,
            payloadSize,
            topic,
            qos: options.qos,
            retain: options.retain,
            ...meta,
            err: serializeError(err) 
          });
          resolve(false);
        } else {
          logger.info('MQTT publish success', {
            duration,
            payloadSize,
            topic,
            qos: options.qos,
            retain: options.retain,
            ...meta
          });
          resolve(true);
        }
      });
    });
  }

  async function publishGeofenceForNodeId(nodeId, requestId, { bumpVersion } = {}) {
    const payload = await db.getNodeGeofencePayload(nodeId);
    const vertices = payload ? extractVerticesFromGeojson(payload.geojson) : [];

    const version = bumpVersion ? await db.bumpNodeGeofenceVersion(nodeId) : await db.getNodeGeofenceVersion(nodeId);

    const msg = {
      request_id: requestId || randomRequestId('req'),
      node_id: Number(nodeId),
      geofence_version: Number(version),
      vertices,
    };

    if (!client.connected) {
      logger.error('MQTT publish attempted while not connected', { url, updateTopic, nodeId });
    }

    logger.info('MQTT geofence publish queued', {
      updateTopic,
      nodeId,
      geofenceVersion: msg.geofence_version,
      requestId: msg.request_id,
      verticesCount: vertices.length,
      connected: client.connected,
    });

    const ok = await publishWithAckTimeout(
      updateTopic,
      JSON.stringify(msg),
      { qos: 1 },
      { updateTopic, nodeId, geofenceVersion: msg.geofence_version, requestId: msg.request_id }
    );

    if (ok) {
      logger.info('MQTT geofence published', { updateTopic, nodeId, geofenceVersion: msg.geofence_version, requestId: msg.request_id });
    }
  }

  async function publishGeofencesForNodeIds(nodeIds, requestIdPrefix, { bumpVersion } = {}) {
    const unique = Array.from(new Set((nodeIds || []).map((n) => Number(n)).filter((n) => Number.isFinite(n))));
    for (const nodeId of unique) {
      await publishGeofenceForNodeId(nodeId, randomRequestId(requestIdPrefix || 'req'), { bumpVersion });
    }
  }

  client.on('message', async (topic, message) => {
    console.log('MQTT message received on topic:', topic, 'payload:', message.toString('utf8'));
    if (topic !== bootTopic) {
      console.log('MQTT: ignoring topic, expected:', bootTopic);
      return;
    }
    try {
      const parsed = JSON.parse(message.toString('utf8'));
      console.log('MQTT boot message parsed:', parsed);
      const reason = String(parsed?.reason || '');
      console.log('MQTT boot reason:', reason);
      if (reason !== 'boot') {
        console.log('MQTT: not a boot request, ignoring');
        return;
      }

      const gatewayId = Number(parsed?.gateway_id);
      const ts = parsed?.ts;
      logger.info('Gateway boot request received', { gatewayId, ts });
      console.log('MQTT: processing boot request for gateway', gatewayId);

      const nodeIds = await db.listNodeIdsWithAnyGeofenceAssignments();
      console.log('MQTT: nodes with geofence assignments:', nodeIds);
      await publishGeofencesForNodeIds(nodeIds, `boot_${gatewayId || 'gw'}`, { bumpVersion: false });
      console.log('MQTT: boot request processed, geofences published');
    } catch (err) {
      console.log('MQTT boot message error:', err);
      logger.error('MQTT boot message handling failed', { err: serializeError(err) });
    }
  });

  return {
    publishGeofencesForNodeIds,
    publishGeofenceForNodeId,
    updateTopic,
    bootTopic,
  };
}

module.exports = {
  createMqttGeofenceSync,
};
