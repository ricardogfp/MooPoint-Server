const { InfluxDB } = require('@influxdata/influxdb-client');
const { logger } = require('./logger');
const { fetch } = require('undici');

function getInfluxConfig() {
  const url = process.env.INFLUXDB_URL || process.env.INFLUX_URL;
  const token = process.env.INFLUXDB_TOKEN || process.env.INFLUX_TOKEN;
  const org = process.env.INFLUXDB_ORG || process.env.INFLUX_ORG;
  const bucket = process.env.INFLUXDB_BUCKET || process.env.INFLUX_BUCKET;
  const measurement = process.env.INFLUX_MEASUREMENT || 'position';
  const timeRangeHours = Number(process.env.INFLUX_TIME_RANGE_HOURS || '1');
  const deviceType = process.env.INFLUX_DEVICE_TYPE || 'tracker';
  const deviceTypeTag = process.env.INFLUX_DEVICE_TYPE_TAG || 'device_type';
  const deviceIdTag = process.env.INFLUX_DEVICE_ID_TAG || 'node_id';

  if (!url || !token || !org || !bucket) {
    const missing = [
      !url && 'INFLUXDB_URL/INFLUX_URL',
      !token && 'INFLUXDB_TOKEN/INFLUX_TOKEN',
      !org && 'INFLUXDB_ORG/INFLUX_ORG',
      !bucket && 'INFLUXDB_BUCKET/INFLUX_BUCKET'
    ].filter(Boolean);
    throw new Error(`Missing env vars: ${missing.join(', ')}`);
  }

  return {
    url,
    token,
    org,
    bucket,
    measurement,
    timeRangeHours,
    deviceType,
    deviceTypeTag,
    deviceIdTag
  };
}

function influxClient() {
  const { url, token } = getInfluxConfig();
  return new InfluxDB({ url, token });
}

async function checkInfluxHealth() {
  const { url } = getInfluxConfig();
  const healthUrl = `${url.replace(/\/$/, '')}/health`;

  const start = Date.now();
  try {
    const resp = await fetch(healthUrl, { method: 'GET' });
    const text = await resp.text();
    const ms = Date.now() - start;

    logger.info('Influx health check', {
      healthUrl,
      status: resp.status,
      ms,
      bodyPreview: text ? text.slice(0, 500) : ''
    });

    return { ok: resp.ok, status: resp.status, body: text };
  } catch (err) {
    const ms = Date.now() - start;
    logger.error('Influx health check failed', { healthUrl, ms, err });
    return { ok: false, status: 0, body: String(err) };
  }
}

function buildLatestNodesFlux(cfg) {
  return `from(bucket: "${cfg.bucket}")
  |> range(start: -${cfg.timeRangeHours}h)
  |> filter(fn: (r) => r._measurement == "${cfg.measurement}")
  |> filter(fn: (r) => r.${cfg.deviceTypeTag} == "tracker" or r.${cfg.deviceTypeTag} == "fence_tracker")
  |> group(columns: ["${cfg.deviceIdTag}", "_field"])
  |> last()
  |> pivot(rowKey: ["${cfg.deviceIdTag}"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["${cfg.deviceIdTag}", "lat", "lon", "batt_percent", "voltage", "_time"])`;
}

// Fence nodes publish to "fence_status" measurement (no lat/lon).
// This query fetches their latest telemetry so they surface in /api/nodes.
function buildLatestFenceNodesFlux(cfg) {
  return `from(bucket: "${cfg.bucket}")
  |> range(start: -${cfg.timeRangeHours}h)
  |> filter(fn: (r) => r._measurement == "fence_status")
  |> group(columns: ["${cfg.deviceIdTag}", "_field"])
  |> last()
  |> pivot(rowKey: ["${cfg.deviceIdTag}"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["${cfg.deviceIdTag}", "batt_percent", "voltage", "rssi", "snr", "_time"])`;
}

function rowToFenceNode(row, cfg) {
  const nodeId = Number(row[cfg.deviceIdTag]);
  if (!Number.isFinite(nodeId)) return null;
  const batt = row.batt_percent !== undefined ? Number(row.batt_percent) : 0;
  const voltage = row.voltage !== undefined ? Number(row.voltage) : null;
  const rssi = row.rssi !== undefined ? Number(row.rssi) : null;
  const snr = row.snr !== undefined ? Number(row.snr) : null;
  const time = row._time ? new Date(row._time) : new Date();
  return {
    nodeId,
    name: `Node ${nodeId}`,
    latitude: NaN,
    longitude: NaN,
    batteryLevel: Number.isFinite(batt) ? Math.round(batt) : 0,
    voltage: voltage !== null ? Number(voltage) : null,
    rssi: rssi !== null && Number.isFinite(rssi) ? Math.round(rssi) : null,
    snr: snr !== null && Number.isFinite(snr) ? snr : null,
    lastUpdated: time.toISOString(),
    breed: null,
    age: null,
    healthStatus: null,
  };
}

function buildNodeByIdFlux(cfg, nodeId) {
  const nodeIdStr = String(nodeId);
  return `from(bucket: "${cfg.bucket}")
  |> range(start: -${cfg.timeRangeHours}h)
  |> filter(fn: (r) => r._measurement == "${cfg.measurement}")
  |> filter(fn: (r) => r.${cfg.deviceIdTag} == "${nodeIdStr}")
  |> group(columns: ["${cfg.deviceIdTag}", "_field"])
  |> last()
  |> pivot(rowKey: ["${cfg.deviceIdTag}"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["${cfg.deviceIdTag}", "lat", "lon", "batt_percent", "voltage", "_time"])`;
}

function buildNodeHistoryFlux(cfg, nodeId, hours, everyMinutes) {
  const nodeIdStr = String(nodeId);
  const hrs = Number.isFinite(Number(hours)) ? Number(hours) : 24;
  const every = Number.isFinite(Number(everyMinutes)) ? Number(everyMinutes) : 1;

  return `from(bucket: "${cfg.bucket}")
  |> range(start: -${hrs}h)
  |> filter(fn: (r) => r._measurement == "${cfg.measurement}")
  |> filter(fn: (r) => r.${cfg.deviceIdTag} == "${nodeIdStr}")
  |> filter(fn: (r) => r._field == "lat" or r._field == "lon" or r._field == "batt_percent" or r._field == "voltage")
  |> aggregateWindow(every: ${every}m, fn: last, createEmpty: false)
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "lat", "lon", "batt_percent", "voltage"])
  |> sort(columns: ["_time"], desc: false)`;
}

function rowToNode(row, cfg) {
  const nodeId = Number(row[cfg.deviceIdTag]);
  const lat = row.lat !== undefined ? Number(row.lat) : NaN;
  const lon = row.lon !== undefined ? Number(row.lon) : NaN;
  const batt = row.batt_percent !== undefined ? Number(row.batt_percent) : 0;
  const voltage = row.voltage !== undefined ? Number(row.voltage) : null;
  const time = row._time ? new Date(row._time) : new Date();

  if (!Number.isFinite(nodeId)) {
    return null;
  }

  return {
    nodeId,
    name: `Node ${nodeId}`,
    latitude: lat,
    longitude: lon,
    batteryLevel: Number.isFinite(batt) ? Math.round(batt) : 0,
    voltage: voltage !== null ? Number(voltage) : null,
    lastUpdated: time.toISOString(),
    breed: null,
    age: null,
    healthStatus: null
  };
}

async function queryRows(fluxQuery, meta) {
  const cfg = getInfluxConfig();
  const queryApi = influxClient().getQueryApi(cfg.org);

  const start = Date.now();
  logger.debug('Influx query start', { ...meta, fluxQuery });

  try {
    const rows = await queryApi.collectRows(fluxQuery);
    const ms = Date.now() - start;

    logger.info('Influx query ok', {
      ...meta,
      ms,
      rowCount: rows.length,
      rowsPreview: rows.slice(0, Number(process.env.LOG_RESULT_PREVIEW_ROWS || '5'))
    });

    return { rows, ms };
  } catch (err) {
    const ms = Date.now() - start;
    logger.error('Influx query failed', { ...meta, ms, err, fluxQuery });
    throw err;
  }
}

async function getLatestNodes() {
  const cfg = getInfluxConfig();

  // Query tracker nodes (position measurement) and fence nodes (fence_status) in parallel.
  const [{ rows: trackerRows }, { rows: fenceRows }] = await Promise.all([
    queryRows(buildLatestNodesFlux(cfg), { query: 'latest_nodes_trackers' }),
    queryRows(buildLatestFenceNodesFlux(cfg), { query: 'latest_nodes_fence' }).catch(() => ({ rows: [] })),
  ]);

  const trackerNodes = trackerRows.map((r) => rowToNode(r, cfg)).filter(Boolean);
  const fenceNodes = fenceRows.map((r) => rowToFenceNode(r, cfg)).filter(Boolean);

  // Merge: tracker data takes precedence if a nodeId appears in both (shouldn't happen).
  const byId = new Map();
  for (const n of [...fenceNodes, ...trackerNodes]) {
    byId.set(n.nodeId, n);
  }
  return Array.from(byId.values());
}

async function getNodeById(nodeId) {
  const cfg = getInfluxConfig();
  const flux = buildNodeByIdFlux(cfg, nodeId);

  const { rows } = await queryRows(flux, { query: 'node_by_id', nodeId: Number(nodeId) });
  const node = rows.map((r) => rowToNode(r, cfg)).filter(Boolean)[0] || null;
  return node;
}

async function getNodeHistory({ nodeId, hours = 24, everyMinutes = 1 }) {
  const cfg = getInfluxConfig();
  const flux = buildNodeHistoryFlux(cfg, nodeId, hours, everyMinutes);
  const meta = { query: 'node_history', nodeId: Number(nodeId), hours: Number(hours), everyMinutes: Number(everyMinutes) };
  const { rows } = await queryRows(flux, meta);

  return rows
    .map((r) => {
      const t = r._time ? new Date(r._time) : null;
      const lat = r.lat !== undefined ? Number(r.lat) : NaN;
      const lon = r.lon !== undefined ? Number(r.lon) : NaN;
      const voltage = r.voltage !== undefined ? Number(r.voltage) : null;
      if (!t) return null;
      return {
        time: t.toISOString(),
        lat: Number.isFinite(lat) ? lat : NaN,
        lon: Number.isFinite(lon) ? lon : NaN,
        voltage: voltage
      };
    })
    .filter(Boolean);
}

async function getBehaviorData({ nodeId, hours = 24 }) {
  const cfg = getInfluxConfig();
  const nodeIdStr = String(nodeId);
  const hrs = Number.isFinite(Number(hours)) ? Number(hours) : 24;

  const flux = `from(bucket: "${cfg.bucket}")
  |> range(start: -${hrs}h)
  |> filter(fn: (r) => r._measurement == "${cfg.measurement}")
  |> filter(fn: (r) => r.${cfg.deviceTypeTag} == "${cfg.deviceType}")
  |> filter(fn: (r) => r.${cfg.deviceIdTag} == "${nodeIdStr}")
  |> filter(fn: (r) => 
    r._field == "ext_behavior_ruminating_s" or 
    r._field == "ext_behavior_grazing_s" or 
    r._field == "ext_behavior_resting_s" or 
    r._field == "ext_behavior_moving_s" or 
    r._field == "ext_behavior_feeding_s" or 
    r._field == "ext_behavior_confidence"
  )
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "ext_behavior_ruminating_s", "ext_behavior_grazing_s", 
                     "ext_behavior_resting_s", "ext_behavior_moving_s", 
                     "ext_behavior_feeding_s", "ext_behavior_confidence"])
  |> sort(columns: ["_time"], desc: false)`;

  const meta = { query: 'behavior_data', nodeId: Number(nodeId), hours: Number(hours) };
  const { rows } = await queryRows(flux, meta);

  return rows.map((r) => {
    const t = r._time ? new Date(r._time) : null;
    if (!t) return null;
    return {
      timestamp: t.toISOString(),
      ruminating_s: r.ext_behavior_ruminating_s || 0,
      grazing_s: r.ext_behavior_grazing_s || 0,
      resting_s: r.ext_behavior_resting_s || 0,
      moving_s: r.ext_behavior_moving_s || 0,
      feeding_s: r.ext_behavior_feeding_s || 0,
      confidence: r.ext_behavior_confidence || 0
    };
  }).filter(Boolean);
}

async function getBehaviorSummary({ nodeId, date }) {
  const cfg = getInfluxConfig();
  const nodeIdStr = String(nodeId);

  // Parse date or use today
  let startDate, endDate;
  if (date) {
    startDate = new Date(date);
    endDate = new Date(date);
    endDate.setDate(endDate.getDate() + 1);
  } else {
    endDate = new Date();
    startDate = new Date();
    startDate.setHours(0, 0, 0, 0);
  }

  const flux = `from(bucket: "${cfg.bucket}")
  |> range(start: ${startDate.toISOString()}, stop: ${endDate.toISOString()})
  |> filter(fn: (r) => r._measurement == "${cfg.measurement}")
  |> filter(fn: (r) => r.${cfg.deviceTypeTag} == "${cfg.deviceType}")
  |> filter(fn: (r) => r.${cfg.deviceIdTag} == "${nodeIdStr}")
  |> filter(fn: (r) =>
    r._field == "ext_behavior_ruminating_s" or
    r._field == "ext_behavior_grazing_s" or
    r._field == "ext_behavior_resting_s" or
    r._field == "ext_behavior_moving_s" or
    r._field == "ext_behavior_feeding_s"
  )
  |> group(columns: ["_field"])
  |> sum()`;

  const meta = { query: 'behavior_summary', nodeId: Number(nodeId), date };
  const { rows } = await queryRows(flux, meta);

  // rows: [{ _field: "ext_behavior_grazing_s", _value: 1800 }, ...]
  const totals = {};
  for (const row of rows) {
    if (row._field) totals[row._field] = Number(row._value) || 0;
  }

  return {
    date: startDate.toISOString().split('T')[0],
    ruminating_minutes: Math.round((totals.ext_behavior_ruminating_s || 0) / 60),
    grazing_minutes: Math.round((totals.ext_behavior_grazing_s || 0) / 60),
    resting_minutes: Math.round((totals.ext_behavior_resting_s || 0) / 60),
    moving_minutes: Math.round((totals.ext_behavior_moving_s || 0) / 60),
    feeding_minutes: Math.round((totals.ext_behavior_feeding_s || 0) / 60),
  };
}

async function getNodeTrackingAge(nodeId) {
  const cfg = getInfluxConfig();
  const flux = `from(bucket: "${cfg.bucket}")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "${cfg.measurement}")
  |> filter(fn: (r) => r.${cfg.deviceTypeTag} == "${cfg.deviceType}")
  |> filter(fn: (r) => r.${cfg.deviceIdTag} == "${String(nodeId)}")
  |> filter(fn: (r) => r._field == "lat")
  |> first()
  |> keep(columns: ["_time"])`;
  const { rows } = await queryRows(flux, { query: 'tracking_age', nodeId });
  if (!rows.length || !rows[0]._time) return null;
  return new Date(rows[0]._time);
}

async function getFenceHistory({ nodeId, hours = 24, everyMinutes = 5 }) {
  const cfg = getInfluxConfig();
  const nodeIdStr = String(nodeId);
  const hrs = Number.isFinite(Number(hours)) ? Number(hours) : 24;
  const every = Number.isFinite(Number(everyMinutes)) ? Number(everyMinutes) : 5;

  const flux = `from(bucket: "${cfg.bucket}")
  |> range(start: -${hrs}h)
  |> filter(fn: (r) => r._measurement == "fence_status")
  |> filter(fn: (r) => r.${cfg.deviceIdTag} == "${nodeIdStr}")
  |> filter(fn: (r) => r._field == "voltage" or r._field == "batt_percent")
  |> aggregateWindow(every: ${every}m, fn: last, createEmpty: false)
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "voltage", "batt_percent"])
  |> sort(columns: ["_time"], desc: false)`;

  const meta = { query: 'fence_history', nodeId: Number(nodeId), hours: hrs, everyMinutes: every };
  const { rows } = await queryRows(flux, meta);

  return rows
    .map((r) => {
      const t = r._time ? new Date(r._time) : null;
      if (!t) return null;
      const voltage = r.voltage !== undefined ? Number(r.voltage) : null;
      const battPercent = r.batt_percent !== undefined ? Number(r.batt_percent) : null;
      return {
        time: t.toISOString(),
        voltage,
        batt_percent: battPercent,
      };
    })
    .filter(Boolean);
}

module.exports = {
  getInfluxConfig,
  checkInfluxHealth,
  getLatestNodes,
  getNodeById,
  getNodeHistory,
  getBehaviorData,
  getBehaviorSummary,
  getNodeTrackingAge,
  getFenceHistory
};
