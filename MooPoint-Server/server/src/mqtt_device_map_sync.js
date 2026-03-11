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

function parseGatewayIdsFromEnv() {
  const raw = String(process.env.MQTT_DEVICE_MAP_GATEWAY_IDS || '').trim();
  if (!raw) return [];
  return raw
    .split(',')
    .map((s) => Number(String(s).trim()))
    .filter((n) => Number.isFinite(n) && n > 0);
}

function buildDeviceMapText(rows) {
  const lines = (rows || [])
    .map((r) => ({
      nodeId: Number(r.nodeId),
      deviceId: Number(r.deviceId),
      deviceKey: r.deviceKey ? String(r.deviceKey).trim().toLowerCase() : '',
    }))
    .filter((r) => Number.isFinite(r.nodeId) && r.nodeId > 0)
    .filter((r) => Number.isFinite(r.deviceId) && r.deviceId > 0)
    .filter((r) => /^[0-9a-f]{64}$/.test(r.deviceKey));

  return lines.map((r) => `${r.nodeId},${r.deviceId},${r.deviceKey}`).join('\n');
}

function createMqttDeviceMapSync({ db, logger }) {
  const url = process.env.MQTT_URL || 'mqtt://127.0.0.1:1883';
  const setTopicFormat = process.env.MQTT_DEVICE_MAP_SET_TOPIC_FMT || 'moopoint/cmd/gateway/{gateway_id}/device_map';
  const stateTopic = process.env.MQTT_DEVICE_MAP_STATE_TOPIC || 'moopoint/telemetry/gateway/+/status';

  const client = mqtt.connect(url, {
    username: process.env.MQTT_USERNAME || undefined,
    password: process.env.MQTT_PASSWORD || undefined,
  });

  function topicForGateway(gatewayId) {
    return String(setTopicFormat).replace('{gateway_id}', String(Number(gatewayId)));
  }

  client.on('connect', () => {
    logger.info('MQTT connected (device_map sync)', { url, stateTopic, setTopicFormat });
    client.subscribe(stateTopic, (err) => {
      if (err) logger.error('MQTT subscribe failed (device_map state)', { stateTopic, err: serializeError(err) });
      else logger.info('MQTT subscribed (device_map state)', { stateTopic });
    });

    const gatewayIds = parseGatewayIdsFromEnv();
    if (gatewayIds.length) {
      // Push at startup so gateways that are already online get it immediately
      publishDeviceMapForGateways(gatewayIds).catch((e) => {
        logger.error('Initial device_map publish failed', { err: serializeError(e) });
      });
    } else {
      logger.info('No MQTT_DEVICE_MAP_GATEWAY_IDS configured; device_map will only publish when triggered via HTTP', {});
    }
  });

  client.on('reconnect', () => {
    logger.info('MQTT reconnecting (device_map sync)', { url });
  });

  client.on('offline', () => {
    logger.error('MQTT offline (device_map sync)', { url });
  });

  client.on('close', () => {
    logger.error('MQTT connection closed (device_map sync)', { url });
  });

  client.on('error', (err) => {
    logger.error('MQTT error (device_map sync)', { err: serializeError(err) });
  });

  client.on('message', (topic, message) => {
    const payload = message ? message.toString('utf8') : '';
    logger.info('MQTT device_map state received', { topic, payload });
  });

  async function publishDeviceMapForGateway(gatewayId, { retain = true } = {}) {
    const gid = Number(gatewayId);
    if (!Number.isFinite(gid) || gid <= 0) throw new Error('invalid_gateway_id');

    const rows = await db.listNodeDeviceCredentials();
    const deviceMap = buildDeviceMapText(rows);

    // Gateway buffer is 1024 bytes; keep headroom for null terminator on device.
    const maxBytes = Number(process.env.MQTT_DEVICE_MAP_MAX_BYTES || '1023');
    if (Buffer.byteLength(deviceMap, 'utf8') > maxBytes) {
      throw new Error(`device_map_too_large_${Buffer.byteLength(deviceMap, 'utf8')}_gt_${maxBytes}`);
    }

    const topic = topicForGateway(gid);
    const options = { qos: 1, retain: Boolean(retain) };

    const startTime = Date.now();
    const payloadSize = Buffer.byteLength(deviceMap, 'utf8');

    logger.info('MQTT publishing device_map', {
      gatewayId: gid,
      topic,
      payloadSize,
      retain: options.retain,
      qos: options.qos,
      connected: client.connected,
    });

    await new Promise((resolve, reject) => {
      client.publish(topic, deviceMap, options, (err) => {
        const duration = Date.now() - startTime;
        if (err) {
          logger.error('MQTT device_map publish failed', {
            duration,
            payloadSize,
            topic,
            qos: options.qos,
            retain: options.retain,
            gatewayId: gid,
            err: serializeError(err)
          });
          reject(err);
        } else {
          logger.info('MQTT device_map publish success', {
            duration,
            payloadSize,
            topic,
            qos: options.qos,
            retain: options.retain,
            gatewayId: gid
          });
          resolve();
        }
      });
    });

    return { ok: true, gatewayId: gid, topic };
  }

  async function publishDeviceMapForGateways(gatewayIds, opts) {
    const unique = Array.from(new Set((gatewayIds || []).map((n) => Number(n)).filter((n) => Number.isFinite(n) && n > 0)));
    const results = [];
    for (const gid of unique) {
      results.push(await publishDeviceMapForGateway(gid, opts));
    }
    return results;
  }

  return {
    publishDeviceMapForGateway,
    publishDeviceMapForGateways,
    parseGatewayIdsFromEnv,
    stateTopic,
    setTopicFormat,
  };
}

module.exports = {
  createMqttDeviceMapSync,
};
