#!/usr/bin/env node
/**
 * MooPoint MQTT Test Script
 *
 * Simulates 4 tracker nodes + 2 fence nodes via MQTT.
 * Tracker nodes cycle through waypoints inside/outside a polygon every 5 minutes
 * to exercise geofence breach detection and real-time updates.
 *
 * Usage:
 *   node server/scripts/mqtt_test.js [options]
 *
 * Options:
 *   --interval <ms>    Tracker publish interval in ms (default: 300000 = 5 min)
 *   --fence-interval <ms>  Fence publish interval in ms (default: 60000 = 1 min)
 *   --fence-fault      Force both fence nodes to report fault voltage (<5000V)
 *   --bucket <name>    InfluxDB bucket for direct writes (default: moopoint_test)
 *
 * Requires MQTT_URL, MQTT_USERNAME, MQTT_PASSWORD in server/.env
 */

'use strict';

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const mqtt = require('mqtt');

// --- CLI args ---
const args = process.argv.slice(2);
const getArg = (flag, def) => {
  const idx = args.indexOf(flag);
  return idx !== -1 && args[idx + 1] ? args[idx + 1] : def;
};
const hasFlag = (flag) => args.includes(flag);

const TRACKER_INTERVAL_MS = parseInt(getArg('--interval', '300000'), 10);
const FENCE_INTERVAL_MS   = parseInt(getArg('--fence-interval', '60000'), 10);
const FORCE_FENCE_FAULT   = hasFlag('--fence-fault');

// Export for PM2
module.exports = {
  trackerInterval: TRACKER_INTERVAL_MS,
  fenceInterval: FENCE_INTERVAL_MS,
  forceFenceFault: FORCE_FENCE_FAULT
};

console.log('=== MooPoint MQTT Test Script ===');
console.log(`Tracker interval : ${TRACKER_INTERVAL_MS / 1000}s`);
console.log(`Fence interval   : ${FENCE_INTERVAL_MS / 1000}s`);
console.log(`Force fence fault: ${FORCE_FENCE_FAULT}`);
console.log('');

// --- MQTT connection ---
const MQTT_URL      = process.env.MQTT_URL      || 'mqtt://127.0.0.1:1883';
const MQTT_USERNAME = process.env.MQTT_USERNAME  || '';
const MQTT_PASSWORD = process.env.MQTT_PASSWORD  || '';

const client = mqtt.connect(MQTT_URL, {
  username: MQTT_USERNAME || undefined,
  password: MQTT_PASSWORD || undefined,
  clientId: `moopoint-test-${Math.random().toString(16).slice(2, 8)}`,
  reconnectPeriod: 3000,
});

// --- Polygon (GeoJSON [lon, lat] order) ---
// The real fence polygon provided by the user
const POLYGON = [
  [-3.6259482321725898, 40.678510292775854],
  [-3.618654570266898,  40.675254224158095],
  [-3.611406653217813,  40.67485495729861 ],
  [-3.610071892707765,  40.68375185694711 ],
  [-3.6205606999632494, 40.687295606707636],
  [-3.6214191100625897, 40.68317421116481 ],
  [-3.6259482321725898, 40.678510292775854],
];

// Point-in-polygon (ray casting) — [lon, lat]
function pointInPolygon(lon, lat, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const xi = poly[i][0], yi = poly[i][1];
    const xj = poly[j][0], yj = poly[j][1];
    const intersect = ((yi > lat) !== (yj > lat)) &&
      (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

// --- Waypoints ---
// Inside polygon (verified):
const A = { lat: 40.6793, lon: -3.6203, label: 'A (inside, NW)' };
const B = { lat: 40.6810, lon: -3.6175, label: 'B (inside, center)' };
const C = { lat: 40.6830, lon: -3.6210, label: 'C (inside, W)' };
const D = { lat: 40.6762, lon: -3.6155, label: 'D (inside, SE)' };
const E = { lat: 40.6845, lon: -3.6190, label: 'E (inside, N)' };

// Outside polygon:
const P = { lat: 40.6720, lon: -3.6240, label: 'P (outside, south breach)' };
const Q = { lat: 40.6900, lon: -3.6145, label: 'Q (outside, north breach)' };
const R = { lat: 40.6760, lon: -3.6060, label: 'R (outside, east breach)' };
const S = { lat: 40.6700, lon: -3.6200, label: 'S (outside, SW breach)' };

// --- Tracker node definitions ---
const TRACKER_NODES = [
  {
    nodeId: 1,
    batteryLevel: 85,
    // Breaches south (P), returns, breaches north (Q), returns
    waypoints: [A, P, B, Q, C, P, A],
  },
  {
    nodeId: 2,
    batteryLevel: 72,
    // Mostly inside, one east breach at step 3 (R)
    waypoints: [B, C, R, D, E, B],
  },
  {
    nodeId: 3,
    batteryLevel: 91,
    // Always inside
    waypoints: [A, B, C, D, E, A],
  },
  {
    nodeId: 4,
    batteryLevel: 58,
    // Starts outside (S), enters polygon, wanders inside, exits again
    waypoints: [S, A, B, C, D, S, A],
  },
];

// --- Behavior profiles (base seconds per ~3600s window) ---
// Each node has a distinct personality; values vary ±20% per cycle.
const BEHAVIOR_PROFILES = {
  1: { ruminating_s:  900, grazing_s: 1800, resting_s:  500, moving_s:  300, feeding_s: 100 }, // active grazer
  2: { ruminating_s: 1200, grazing_s: 1000, resting_s:  800, moving_s:  400, feeding_s: 200 }, // balanced
  3: { ruminating_s: 1800, grazing_s:  700, resting_s:  700, moving_s:  250, feeding_s: 150 }, // heavy ruminant
  4: { ruminating_s:  600, grazing_s:  900, resting_s:  400, moving_s: 1400, feeding_s: 300 }, // restless mover
};

function makeBehavior(nodeId) {
  const base = BEHAVIOR_PROFILES[nodeId] || BEHAVIOR_PROFILES[1];
  const vary = (v) => Math.round(v * (0.8 + Math.random() * 0.4)); // ±20%
  return {
    behavior_ruminating_s: vary(base.ruminating_s),
    behavior_grazing_s:    vary(base.grazing_s),
    behavior_resting_s:    vary(base.resting_s),
    behavior_moving_s:     vary(base.moving_s),
    behavior_feeding_s:    vary(base.feeding_s),
    behavior_confidence:   randInt(75, 98),
  };
}

// Mutable state per tracker
const trackerState = TRACKER_NODES.map((n) => ({
  ...n,
  waypointIdx: 0,
  battery: n.batteryLevel,
  cycles: randInt(50, 200), // realistic non-zero starting cycle count
}));

// --- Fence node definitions ---
const FENCE_NODES = [
  {
    nodeId: 42,
    voltage: FORCE_FENCE_FAULT ? 3000 : 6500, // healthy above 5000V
    battery: 88,
  },
  {
    nodeId: 43,
    voltage: FORCE_FENCE_FAULT ? 1500 : 3200, // always fault (<5000V)
    battery: 55,
  },
];

const fenceState = FENCE_NODES.map((n) => ({ ...n }));

// --- Helpers ---
function jitter(val, range = 0.0001) {
  return val + (Math.random() * 2 - 1) * range;
}

function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randFloat(min, max, decimals = 1) {
  return parseFloat((Math.random() * (max - min) + min).toFixed(decimals));
}

function ts() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19);
}

// --- Publish tracker position ---
function publishTracker(state) {
  const wp = state.waypoints[state.waypointIdx];
  const lat = jitter(wp.lat);
  const lon = jitter(wp.lon);
  const inside = pointInPolygon(lon, lat, POLYGON);

  // Raw battery voltage (mV) derived from percent
  const battMv = 3300 + Math.round(state.battery * 12);
  const sats = randInt(6, 12);

  const payload = {
    lat,
    lon,
    batt:         battMv,
    batt_percent: state.battery,
    voltage:      battMv,
    gps_valid:    true,
    sats,
    rssi: randInt(-100, -65),
    snr:  randFloat(1.5, 9.0),
    ext: {
      // GPS detail
      gps_fix:      1,
      gps_fail:     0,
      gps_hot:      Math.random() < 0.8 ? 1 : 0,  // warm fix 80% of the time
      gps_fix_time: randInt(1, 8),                 // seconds to acquire fix
      gps_sats:     sats,
      // LoRa RF (as seen by the gateway)
      tx_power:     randInt(10, 20),
      tracker_rssi: randInt(-110, -60),
      tracker_snr:  randFloat(1.0, 9.0),
      // System
      power_mode:   1,               // 1 = normal, 0 = low-power
      cycles:       state.cycles,
      // Behavior (seconds per ~3600s observation window)
      ...makeBehavior(state.nodeId),
    },
  };

  const topic = `moopoint/telemetry/tracker/${state.nodeId}/position`;
  client.publish(topic, JSON.stringify(payload), { qos: 0, retain: false });

  const beh = payload.ext;
  console.log(
    `[${ts()}] TRACKER node=${state.nodeId}  wp=${wp.label}  ` +
    `lat=${lat.toFixed(6)} lon=${lon.toFixed(6)}  ` +
    `${inside ? '✅ INSIDE ' : '🚨 OUTSIDE'}  batt=${state.battery}%  ` +
    `cycles=${state.cycles}  sats=${sats}  ` +
    `graze=${beh.behavior_grazing_s}s rum=${beh.behavior_ruminating_s}s ` +
    `rest=${beh.behavior_resting_s}s move=${beh.behavior_moving_s}s`
  );

  // Advance waypoint and system state
  state.waypointIdx = (state.waypointIdx + 1) % state.waypoints.length;
  state.battery = Math.max(5, state.battery - randInt(0, 1));
  state.cycles++;
}

// --- Publish fence status ---
function publishFence(state) {
  const payload = {
    node_id: state.nodeId,
    batt_percent: state.battery,
    voltage: state.voltage,
    rssi: randInt(-95, -70),
    snr: randFloat(2.0, 7.0),
    ts: Math.floor(Date.now() / 1000),
  };

  const topic = `moopoint/telemetry/fence/${state.nodeId}/status`;
  client.publish(topic, JSON.stringify(payload), { qos: 0, retain: false });

  const faultLabel = state.voltage < 5000 ? '⚡ FAULT' : '✅ OK   ';
  console.log(
    `[${ts()}] FENCE  node=${state.nodeId}  voltage=${state.voltage}V ${faultLabel}  batt=${state.battery}%`
  );

  // Slowly drain battery
  state.battery = Math.max(3, state.battery - (Math.random() < 0.3 ? 1 : 0));
}

// --- Main ---
client.on('connect', () => {
  console.log(`[${ts()}] ✅ Connected to MQTT broker at ${MQTT_URL}`);
  console.log('');

  // Publish immediately on connect
  for (const state of trackerState) publishTracker(state);
  for (const state of fenceState)   publishFence(state);

  // Tracker: every TRACKER_INTERVAL_MS
  const trackerTimer = setInterval(() => {
    console.log('');
    for (const state of trackerState) publishTracker(state);
  }, TRACKER_INTERVAL_MS);

  // Fence: every FENCE_INTERVAL_MS
  const fenceTimer = setInterval(() => {
    for (const state of fenceState) publishFence(state);
  }, FENCE_INTERVAL_MS);

  // Graceful shutdown
  process.on('SIGINT', () => {
    console.log(`\n[${ts()}] Shutting down — publishing offline fence status...`);
    for (const state of fenceState) {
      const payload = {
        node_id: state.nodeId,
        batt_percent: state.battery,
        voltage: state.voltage,
        rssi: -120,
        snr: 0,
        ts: Math.floor(Date.now() / 1000),
      };
      client.publish(`moopoint/telemetry/fence/${state.nodeId}/status`, JSON.stringify(payload));
    }
    clearInterval(trackerTimer);
    clearInterval(fenceTimer);
    setTimeout(() => { client.end(); process.exit(0); }, 500);
  });
});

client.on('error', (err) => {
  console.error(`[${ts()}] ❌ MQTT error:`, err.message);
});

client.on('reconnect', () => {
  console.log(`[${ts()}] 🔄 Reconnecting to MQTT broker...`);
});

client.on('offline', () => {
  console.log(`[${ts()}] ⚠️  MQTT client offline`);
});
