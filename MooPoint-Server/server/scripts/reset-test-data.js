#!/usr/bin/env node
/**
 * MooPoint — Reset Test Data
 *
 * Clears all test data:
 *   1. Deletes all measurements from the InfluxDB test bucket (moopoint_test)
 *      using the InfluxDB v2 HTTP Delete API (no extra packages needed).
 *   2. Deletes test node rows from Postgres (node IDs 1–4, 42, 43)
 *      and their related records.
 *
 * Usage:
 *   node server/scripts/reset-test-data.js [--bucket <name>]
 *
 * Options:
 *   --bucket <name>   InfluxDB bucket to wipe (default: moopoint_test)
 *   --pg-only         Skip InfluxDB, only clean Postgres
 *   --influx-only     Skip Postgres, only clean InfluxDB
 */

'use strict';

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { fetch } = require('undici');
const { Pool }  = require('pg');

// --- CLI args ---
const args        = process.argv.slice(2);
const getArg      = (flag, def) => { const i = args.indexOf(flag); return i !== -1 && args[i + 1] ? args[i + 1] : def; };
const hasFlag     = (flag) => args.includes(flag);

const BUCKET      = getArg('--bucket', 'moopoint_test');
const PG_ONLY     = hasFlag('--pg-only');
const INFLUX_ONLY = hasFlag('--influx-only');

// Test node IDs created by mqtt_test.js
const TEST_NODE_IDS = [1, 2, 3, 4, 42, 43];

function ts() { return new Date().toISOString().replace('T', ' ').slice(0, 19); }

// --- InfluxDB delete via HTTP ---
async function resetInflux() {
  const url   = (process.env.INFLUXDB_URL   || process.env.INFLUX_URL   || '').replace(/\/$/, '');
  const token = process.env.INFLUXDB_TOKEN  || process.env.INFLUX_TOKEN;
  const org   = process.env.INFLUXDB_ORG    || process.env.INFLUX_ORG;

  if (!url || !token || !org) {
    console.error('❌ Missing INFLUXDB_URL / INFLUXDB_TOKEN / INFLUXDB_ORG in .env');
    process.exit(1);
  }

  const deleteUrl = `${url}/api/v2/delete?org=${encodeURIComponent(org)}&bucket=${encodeURIComponent(BUCKET)}`;

  console.log(`[${ts()}] Deleting all data from InfluxDB bucket "${BUCKET}" ...`);

  const resp = await fetch(deleteUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Token ${token}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify({
      start: '1970-01-01T00:00:00Z',
      stop:  new Date().toISOString(),
    }),
  });

  if (resp.status === 204) {
    console.log(`[${ts()}] ✅ InfluxDB bucket "${BUCKET}" wiped.`);
  } else if (resp.status === 404) {
    console.warn(`[${ts()}] ⚠️  Bucket "${BUCKET}" not found — nothing to delete.`);
  } else {
    const body = await resp.text();
    throw new Error(`InfluxDB delete failed (HTTP ${resp.status}): ${body}`);
  }
}

// --- Postgres cleanup ---
async function resetPostgres() {
  const pool = new Pool(
    process.env.DATABASE_URL
      ? {
          connectionString: process.env.DATABASE_URL,
          ssl: process.env.PGSSL === 'true' ? { rejectUnauthorized: false } : undefined,
        }
      : {
          host:     process.env.PGHOST     || '127.0.0.1',
          port:     Number(process.env.PGPORT || 5432),
          user:     process.env.PGUSER     || 'postgres',
          password: process.env.PGPASSWORD || '',
          database: process.env.PGDATABASE || 'moopoint',
          ssl: process.env.PGSSL === 'true' ? { rejectUnauthorized: false } : undefined,
        }
  );

  console.log(`[${ts()}] Deleting test nodes (IDs: ${TEST_NODE_IDS.join(', ')}) from Postgres ...`);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Delete from dependent tables first (FK constraints)
    for (const table of [
      'node_events',
      'geofence_assignments',
      'geofence_state',
      'node_geofence_versions',
      'tracker_configs',
      'config_push_status',
    ]) {
      // Some tables may not exist yet — ignore missing table errors
      try {
        const res = await client.query(
          `DELETE FROM ${table} WHERE node_id = ANY($1::int[])`,
          [TEST_NODE_IDS]
        );
        if (res.rowCount > 0) {
          console.log(`[${ts()}]   ${table}: deleted ${res.rowCount} row(s)`);
        }
      } catch (e) {
        if (e.code !== '42P01') throw e; // 42P01 = undefined_table
      }
    }

    // Delete the nodes themselves
    const res = await client.query(
      'DELETE FROM nodes WHERE node_id = ANY($1::int[]) RETURNING node_id',
      [TEST_NODE_IDS]
    );
    const deleted = res.rows.map(r => r.node_id).join(', ') || 'none';
    console.log(`[${ts()}]   nodes: deleted ${res.rowCount} row(s) (IDs: ${deleted})`);

    await client.query('COMMIT');
    console.log(`[${ts()}] ✅ Postgres test data removed.`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

// --- Main ---
(async () => {
  try {
    if (!INFLUX_ONLY) await resetInflux();
    if (!PG_ONLY)     await resetPostgres();
    console.log(`\n[${ts()}] ✅ Reset complete. Safe to switch back to real data.`);
    console.log(`   Run: bash server/scripts/use-real-data.sh`);
  } catch (err) {
    console.error(`[${ts()}] ❌ Reset failed:`, err.message || err);
    process.exit(1);
  }
})();
