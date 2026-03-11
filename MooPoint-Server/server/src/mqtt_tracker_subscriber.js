'use strict';

const mqtt = require('mqtt');
const { InfluxDB, Point } = require('@influxdata/influxdb-client');

const TRACKER_TOPIC = 'moopoint/telemetry/tracker/+/position';
const MEASUREMENT = 'position';
const BATTERY_LOW_THRESHOLD = 15;       // percent
const BATTERY_ALERT_COOLDOWN_MS = 3_600_000; // 1 hour

// In-memory cooldown map: nodeId -> lastAlertTime (ms)
const _battCooldowns = new Map();

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

/**
 * @param {object} opts
 * @param {import('./logger').Logger} opts.logger
 * @param {import('./db')} opts.db          Postgres db module (already initialised)
 * @param {Function} opts.broadcast         ws.broadcast(payload) — sends to all WS clients
 * @returns {{ client: mqtt.MqttClient, topic: string } | null}
 */
function createMqttTrackerSubscriber({ logger, db, broadcast }) {
  // Check if tracker subscriber is enabled
  const enabled = process.env.MQTT_TRACKER_SUBSCRIBER_ENABLED === 'true';
  if (!enabled) {
    logger.info('MQTT tracker subscriber disabled (set MQTT_TRACKER_SUBSCRIBER_ENABLED=true to enable)');
    return null;
  }

  // --- InfluxDB write client ---
  const influxUrl   = process.env.INFLUXDB_URL   || process.env.INFLUX_URL;
  const influxToken = process.env.INFLUXDB_TOKEN || process.env.INFLUX_TOKEN;
  const influxOrg   = process.env.INFLUXDB_ORG   || process.env.INFLUX_ORG;
  const influxBucket= process.env.INFLUXDB_BUCKET|| process.env.INFLUX_BUCKET;

  let writeApi = null;
  if (influxUrl && influxToken && influxOrg && influxBucket) {
    const influxClient = new InfluxDB({ url: influxUrl, token: influxToken });
    writeApi = influxClient.getWriteApi(influxOrg, influxBucket, 'ms');
    writeApi.useDefaultTags({ device_type: 'tracker' });
    logger.info('MQTT tracker subscriber: InfluxDB write API ready', { influxUrl, influxBucket });
  } else {
    logger.warn(
      'MQTT tracker subscriber: InfluxDB credentials missing — telemetry will NOT be persisted',
      { influxUrl: !!influxUrl, influxToken: !!influxToken, influxOrg: !!influxOrg, influxBucket: !!influxBucket }
    );
  }

  // --- MQTT connection ---
  const mqttUrl      = process.env.MQTT_URL      || 'mqtt://127.0.0.1:1883';
  const mqttUsername = process.env.MQTT_USERNAME || undefined;
  const mqttPassword = process.env.MQTT_PASSWORD || undefined;

  const client = mqtt.connect(mqttUrl, {
    username: mqttUsername,
    password: mqttPassword,
    clientId: 'mqtt-tracker-subscriber',
    reconnectPeriod: 5000,
  });

  client.on('connect', () => {
    logger.info('MQTT tracker subscriber connected', {
      url: mqttUrl,
      topic: TRACKER_TOPIC,
      clientId: client.options.clientId
    });

    client.subscribe(TRACKER_TOPIC, { qos: 0 }, (err) => {
      if (err) {
        logger.error('MQTT tracker subscribe failed', {
          topic: TRACKER_TOPIC,
          err: serializeError(err)
        });
      } else {
        logger.info('MQTT tracker subscribed', { topic: TRACKER_TOPIC });
      }
    });
  });

  client.on('message', async (topic, message) => {
    const raw = message ? message.toString('utf8') : '';
    const payloadSize = Buffer.byteLength(raw, 'utf8');

    // Extract node ID from topic: moopoint/telemetry/tracker/{nodeId}/position
    const topicParts = topic.split('/');
    const topicNodeId = topicParts[3] ? Number(topicParts[3]) : null;

    let data;
    try {
      data = JSON.parse(raw);
    } catch (parseErr) {
      logger.error('MQTT tracker: JSON parse error', {
        topic,
        payloadSize,
        rawPreview: raw.substring(0, 200),
        err: serializeError(parseErr),
      });
      return;
    }

    // --- Resolve node_id ---
    const nodeId = Number(data.node_id ?? topicNodeId);
    if (!Number.isFinite(nodeId) || nodeId < 1 || nodeId > 255) {
      logger.warn('MQTT tracker: invalid node_id', { topic, nodeId, data });
      return;
    }

    // Extract position and telemetry
    const lat      = data.lat        != null ? Number(data.lat)        : null;
    const lon      = data.lon        != null ? Number(data.lon)        : null;
    const battPct  = data.batt_percent != null ? Number(data.batt_percent) : null;
    const battMv   = data.batt      != null ? Number(data.batt)       : null;
    const voltage  = data.voltage   != null ? Number(data.voltage)    : null;
    const gpsValid = data.gps_valid != null ? Boolean(data.gps_valid) : null;
    const sats     = data.sats      != null ? Number(data.sats)       : null;
    const rssi     = data.rssi      != null ? Number(data.rssi)       : null;
    const snr      = data.snr       != null ? Number(data.snr)        : null;
    const ext      = data.ext       || {};
    const ts       = new Date();

    logger.info('MQTT tracker position received', {
      nodeId,
      lat,
      lon,
      battPct,
      rssi,
      snr,
      hasExtended: Object.keys(ext).length > 0,
    });

    // --- 1. Write to InfluxDB ---
    if (writeApi) {
      try {
        const point = new Point(MEASUREMENT)
          .tag('node_id', String(nodeId));

        // Position — use same field names as Telegraf ('lat'/'lon') so Flux query can find them
        if (lat !== null) point.floatField('lat', lat);
        if (lon !== null) point.floatField('lon', lon);

        // Battery & power
        if (battPct !== null) point.intField('batt_percent', Math.round(battPct));
        if (battMv !== null)  point.intField('batt',         Math.round(battMv));
        if (voltage !== null) point.intField('voltage',      Math.round(voltage));

        // GPS
        if (gpsValid !== null) point.booleanField('gps_valid', gpsValid);
        if (sats !== null)     point.intField('sats',          Math.round(sats));

        // LoRa RF
        if (rssi !== null) point.intField('rssi',  Math.round(rssi));
        if (snr !== null)  point.floatField('snr', snr);

        // Extended metrics — always written as float to avoid InfluxDB field-type
        // conflicts when firmware sends integer-like values (e.g. snr=5) on one
        // packet and true floats (e.g. snr=5.5) on the next.
        for (const [key, val] of Object.entries(ext)) {
          if (val === null || val === undefined) continue;
          const numVal = Number(val);
          if (!isNaN(numVal)) {
            point.floatField(`ext_${key}`, numVal);
          }
        }

        point.timestamp(ts);
        writeApi.writePoint(point);
        await writeApi.flush();

        logger.debug('MQTT tracker: wrote InfluxDB point', { nodeId, measurement: MEASUREMENT });
      } catch (influxErr) {
        logger.error('MQTT tracker: InfluxDB write failed', {
          nodeId,
          err: serializeError(influxErr),
        });
      }
    }

    // --- 2. Ensure node exists in Postgres with node_type='tracker' ---
    try {
      await db.upsertNodeInfo(nodeId, { nodeType: 'tracker' });
    } catch (dbErr) {
      logger.error('MQTT tracker: upsertNodeInfo failed', {
        nodeId,
        err: serializeError(dbErr),
      });
    }

    // --- 3. Broadcast real-time telemetry update via WebSocket ---
    if (typeof broadcast === 'function') {
      try {
        broadcast({
          type: 'telemetry_update',
          nodeId,
          nodeType:     'tracker',
          latitude:     lat,
          longitude:    lon,
          batteryLevel: battPct !== null ? Math.round(battPct) : null,
          rssi:         rssi !== null ? Math.round(rssi) : null,
          lastUpdated:  ts.toISOString(),
        });
      } catch (wsErr) {
        logger.error('MQTT tracker: broadcast failed', { nodeId, err: serializeError(wsErr) });
      }
    }

    // --- 4. Battery low detection ---
    if (battPct !== null && battPct < BATTERY_LOW_THRESHOLD) {
      const now = Date.now();
      const lastAlert = _battCooldowns.get(nodeId) || 0;
      if (now - lastAlert >= BATTERY_ALERT_COOLDOWN_MS) {
        _battCooldowns.set(nodeId, now);
        logger.warn('MQTT tracker: battery low detected', { nodeId, battPct });
        try {
          await db.insertNodeEvent({
            nodeId,
            type:      'battery_low',
            severity:  'warning',
            message:   `Tracker battery low: ${battPct}%`,
            eventTime: ts.toISOString(),
            lat:       lat ?? null,
            lon:       lon ?? null,
          });
        } catch (evErr) {
          logger.error('MQTT tracker: insertNodeEvent (battery_low) failed', { nodeId, err: serializeError(evErr) });
        }
        if (typeof broadcast === 'function') {
          try {
            broadcast({
              type:      'node_alert',
              alertType: 'battery_low',
              nodeId,
              battPct,
              message:   `Tracker Node ${nodeId} battery low: ${battPct}%`,
            });
          } catch (wsErr) {
            logger.error('MQTT tracker: battery alert broadcast failed', { nodeId, err: serializeError(wsErr) });
          }
        }
      }
    }
  });

  client.on('reconnect', () => {
    logger.info('MQTT tracker subscriber reconnecting', { url: mqttUrl });
  });

  client.on('offline', () => {
    logger.warn('MQTT tracker subscriber offline', { url: mqttUrl });
  });

  client.on('close', () => {
    logger.warn('MQTT tracker subscriber connection closed', { url: mqttUrl });
  });

  client.on('error', (err) => {
    logger.error('MQTT tracker subscriber error', { url: mqttUrl, err: serializeError(err) });
  });

  return {
    client,
    topic: TRACKER_TOPIC
  };
}

module.exports = {
  createMqttTrackerSubscriber,
};
