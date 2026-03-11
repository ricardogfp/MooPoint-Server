/**
 * mqtt_fence_subscriber.js
 *
 * Subscribes to fence-node telemetry topics published by the LoRa gateway:
 *
 *   moopoint/telemetry/fence/+/status
 *
 * Each message is a JSON payload with:
 *   {
 *     "node_id"      : 42,     // integer node ID (1-255)
 *     "batt_percent" : 78,     // battery % (0-100)
 *     "voltage"      : 8200,   // electric fence voltage in Volts (integer)
 *     "rssi"         : -85,    // LoRa RSSI in dBm
 *     "snr"          : 5.5,    // LoRa SNR in dB
 *     "ts"           : 1710000000  // Unix timestamp (seconds), optional
 *   }
 *
 * NOTE: Fence nodes have NO GPS. Their physical position is set once during
 * placement and stored as staticLat/staticLon in Postgres. The server's
 * applyFriendlyNames() function returns those static coordinates to clients.
 *
 * The subscriber:
 *   1. Writes a `fence_status` InfluxDB measurement point with:
 *        device_type = "fence_tracker"
 *        node_id     = <node_id>
 *        Fields: batt_percent, voltage, rssi, snr
 *   2. Calls ensureNodesExist() to register new fence nodes in Postgres.
 *   3. Broadcasts a WebSocket `telemetry_update` event so the Flutter app
 *      refreshes battery/voltage data in real-time (no position included —
 *      the app already knows the static position).
 *   4. If voltage < VOLTAGE_THRESHOLD: logs a node_event and broadcasts
 *      a `node_alert` WebSocket event.
 *
 * Enable with env var:
 *   MQTT_FENCE_SUBSCRIBER_ENABLED=true
 *
 * Uses the same MQTT broker connection parameters as mqtt_tracker_subscriber:
 *   MQTT_URL, MQTT_USERNAME, MQTT_PASSWORD
 */

'use strict';

const mqtt = require('mqtt');
const { InfluxDB, Point } = require('@influxdata/influxdb-client');

const VOLTAGE_THRESHOLD = 5000;      // Volts — below this triggers a fault alert
const VOLTAGE_ALERT_COOLDOWN_MS = 3_600_000; // 1 hour between repeated alerts
const BATTERY_LOW_THRESHOLD = 15;    // percent
const BATTERY_ALERT_COOLDOWN_MS = 3_600_000;
const FENCE_TOPIC = 'moopoint/telemetry/fence/+/status';
const MEASUREMENT = 'fence_status';

// In-memory cooldown maps: nodeId -> lastAlertTime (ms)
const _voltageCooldowns = new Map();
const _battCooldowns = new Map();

function serializeError(err) {
  if (!err) return err;
  if (err instanceof Error) {
    return { name: err.name, message: err.message, stack: err.stack, code: err.code };
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
function createMqttFenceSubscriber({ logger, db, broadcast }) {
  const enabled = process.env.MQTT_FENCE_SUBSCRIBER_ENABLED === 'true';
  if (!enabled) {
    logger.info(
      'MQTT fence subscriber disabled (set MQTT_FENCE_SUBSCRIBER_ENABLED=true to enable)'
    );
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
    writeApi.useDefaultTags({ device_type: 'fence_tracker' });
    logger.info('MQTT fence subscriber: InfluxDB write API ready', { influxUrl, influxBucket });
  } else {
    logger.warn(
      'MQTT fence subscriber: InfluxDB credentials missing — telemetry will NOT be persisted',
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
    clientId: 'mqtt-fence-subscriber',
    reconnectPeriod: 5000,
  });

  client.on('connect', () => {
    logger.info('MQTT fence subscriber connected', { mqttUrl, topic: FENCE_TOPIC });
    client.subscribe(FENCE_TOPIC, { qos: 0 }, (err) => {
      if (err) {
        logger.error('MQTT fence subscribe failed', { topic: FENCE_TOPIC, err: serializeError(err) });
      } else {
        logger.info('MQTT fence subscribed', { topic: FENCE_TOPIC });
      }
    });
  });

  client.on('message', async (topic, message) => {
    const raw = message ? message.toString('utf8') : '';

    // Extract node_id from topic: moopoint/telemetry/fence/{nodeId}/status
    const topicParts = topic.split('/');
    const topicNodeId = topicParts[3] ? Number(topicParts[3]) : null;

    let data;
    try {
      data = JSON.parse(raw);
    } catch (parseErr) {
      logger.error('MQTT fence: JSON parse error', {
        topic,
        rawPreview: raw.substring(0, 200),
        err: serializeError(parseErr),
      });
      return;
    }

    // --- Resolve node_id ---
    const nodeId = Number(data.node_id ?? topicNodeId);
    if (!Number.isFinite(nodeId) || nodeId < 1 || nodeId > 255) {
      logger.warn('MQTT fence: invalid node_id', { topic, nodeId, data });
      return;
    }

    // Fence nodes have no GPS — position comes from staticLat/staticLon in Postgres
    const battPct = data.batt_percent != null ? Number(data.batt_percent) : null;
    const voltage = data.voltage      != null ? Number(data.voltage)      : null;
    const rssi    = data.rssi         != null ? Number(data.rssi)         : null;
    const snr     = data.snr          != null ? Number(data.snr)          : null;
    const ts      = data.ts           != null ? new Date(Number(data.ts) * 1000) : new Date();

    logger.info('MQTT fence telemetry received', {
      nodeId, battPct, voltage, rssi, snr,
      ts: ts.toISOString(),
    });

    // --- 1. Write to InfluxDB ---
    if (writeApi) {
      try {
        const point = new Point(MEASUREMENT)
          .tag('node_id', String(nodeId));

        if (battPct !== null) point.intField('batt_percent', Math.round(battPct));
        if (voltage !== null) point.intField('voltage',      Math.round(voltage));
        if (rssi    !== null) point.intField('rssi',         Math.round(rssi));
        if (snr     !== null) point.floatField('snr',        snr);

        point.timestamp(ts);
        writeApi.writePoint(point);
        await writeApi.flush();

        logger.debug('MQTT fence: wrote InfluxDB point', { nodeId, measurement: MEASUREMENT });
      } catch (influxErr) {
        logger.error('MQTT fence: InfluxDB write failed', {
          nodeId,
          err: serializeError(influxErr),
        });
      }
    }

    // --- 2. Ensure node exists in Postgres with node_type='fence' ---
    // ensureNodesExist() only inserts node_id; use upsertNodeInfo so node_type
    // is set to 'fence', which lets applyFriendlyNames() set isNew=true for
    // unplaced nodes and show the placement banner in the Flutter app.
    try {
      await db.upsertNodeInfo(nodeId, { nodeType: 'fence' });
    } catch (dbErr) {
      logger.error('MQTT fence: upsertNodeInfo failed', {
        nodeId,
        err: serializeError(dbErr),
      });
    }

    // --- 3. Broadcast real-time telemetry update via WebSocket ---
    // Position is NOT included — clients use staticLat/staticLon from the REST API.
    if (typeof broadcast === 'function') {
      try {
        broadcast({
          type: 'telemetry_update',
          nodeId,
          nodeType:     'fence',
          batteryLevel: battPct !== null ? Math.round(battPct) : null,
          voltage:      voltage !== null ? Math.round(voltage)  : null,
          rssi:         rssi    !== null ? Math.round(rssi)     : null,
          lastUpdated:  ts.toISOString(),
        });
      } catch (wsErr) {
        logger.error('MQTT fence: broadcast failed', { nodeId, err: serializeError(wsErr) });
      }
    }

    // --- 4. Voltage fault detection ---
    if (voltage !== null && voltage < VOLTAGE_THRESHOLD) {
      const now = Date.now();
      const lastAlert = _voltageCooldowns.get(nodeId) || 0;

      if (now - lastAlert >= VOLTAGE_ALERT_COOLDOWN_MS) {
        _voltageCooldowns.set(nodeId, now);

        logger.warn('MQTT fence: voltage fault detected', { nodeId, voltage, threshold: VOLTAGE_THRESHOLD });

        // Log to Postgres node_events
        try {
          await db.insertNodeEvent({
            nodeId,
            type:      'voltage_low',
            severity:  'error',
            message:   `Fence voltage fault: ${voltage}V (threshold ${VOLTAGE_THRESHOLD}V)`,
            eventTime: ts.toISOString(),
            lat:       null,
            lon:       null,
          });
        } catch (evErr) {
          logger.error('MQTT fence: insertNodeEvent failed', { nodeId, err: serializeError(evErr) });
        }

        // Broadcast node_alert WebSocket event
        if (typeof broadcast === 'function') {
          try {
            broadcast({
              type:      'node_alert',
              alertType: 'voltage_low',
              nodeId,
              voltage,
              message:   `Fence fault on Node ${nodeId}: ${voltage}V`,
            });
          } catch (wsErr) {
            logger.error('MQTT fence: alert broadcast failed', { nodeId, err: serializeError(wsErr) })
          }
        }
      } else {
        logger.debug('MQTT fence: voltage fault suppressed (cooldown)', {
          nodeId, voltage, cooldownRemainingMs: VOLTAGE_ALERT_COOLDOWN_MS - (now - lastAlert)
        });
      }
    }

    // --- 5. Battery low detection ---
    if (battPct !== null && battPct < BATTERY_LOW_THRESHOLD) {
      const now = Date.now();
      const lastBattAlert = _battCooldowns.get(nodeId) || 0;
      if (now - lastBattAlert >= BATTERY_ALERT_COOLDOWN_MS) {
        _battCooldowns.set(nodeId, now);
        logger.warn('MQTT fence: battery low detected', { nodeId, battPct });
        try {
          await db.insertNodeEvent({
            nodeId,
            type:      'battery_low',
            severity:  'warning',
            message:   `Fence battery low: ${battPct}%`,
            eventTime: ts.toISOString(),
            lat:       null,
            lon:       null,
          });
        } catch (evErr) {
          logger.error('MQTT fence: insertNodeEvent (battery_low) failed', { nodeId, err: serializeError(evErr) });
        }
        if (typeof broadcast === 'function') {
          try {
            broadcast({
              type:      'node_alert',
              alertType: 'battery_low',
              nodeId,
              battPct,
              message:   `Fence Node ${nodeId} battery low: ${battPct}%`,
            });
          } catch (wsErr) {
            logger.error('MQTT fence: battery alert broadcast failed', { nodeId, err: serializeError(wsErr) });
          }
        }
      }
    }
  });

  client.on('reconnect', () => {
    logger.info('MQTT fence subscriber reconnecting', { mqttUrl });
  });

  client.on('offline', () => {
    logger.warn('MQTT fence subscriber offline', { mqttUrl });
  });

  client.on('close', () => {
    logger.warn('MQTT fence subscriber connection closed', { mqttUrl });
  });

  client.on('error', (err) => {
    logger.error('MQTT fence subscriber error', { mqttUrl, err: serializeError(err) });
  });

  return { client, topic: FENCE_TOPIC };
}

module.exports = { createMqttFenceSubscriber };
