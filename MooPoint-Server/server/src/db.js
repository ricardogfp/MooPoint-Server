const { Pool } = require('pg');

let poolPromise = null;

// Simple logger for debugging when main logger isn't available
const debug = {
  info: (msg, data) => console.log(msg, data ? JSON.stringify(data) : ''),
  error: (msg, data) => console.error(msg, data ? JSON.stringify(data) : '')
};

function createPool() {
  const databaseUrl = process.env.DATABASE_URL;
  if (databaseUrl && databaseUrl.trim()) {
    return new Pool({
      connectionString: databaseUrl,
      ssl: process.env.PGSSL === 'true' || process.env.PGSSL === '1' ? { rejectUnauthorized: false } : undefined,
    });
  }
  return new Pool({
    host: process.env.PGHOST || '127.0.0.1',
    port: Number(process.env.PGPORT || 5432),
    user: process.env.PGUSER || 'postgres',
    password: process.env.PGPASSWORD || '',
    database: process.env.PGDATABASE || 'moopoint',
    ssl: process.env.PGSSL === 'true' || process.env.PGSSL === '1' ? { rejectUnauthorized: false } : undefined,
  });
}

async function initDb() {
  if (poolPromise) return poolPromise;

  poolPromise = (async () => {
    const pool = createPool();

    // Bootstraps schema (idempotent). Keeps the same logical structure as SQLite version.
    await pool.query(`
      CREATE TABLE IF NOT EXISTS nodes (
        node_id INTEGER PRIMARY KEY,
        friendly_name TEXT,
        device_id INTEGER,
        device_key TEXT,
        node_type TEXT DEFAULT 'cow',
        static_lat DOUBLE PRECISION,
        static_lon DOUBLE PRECISION,
        breed TEXT,
        age INTEGER,
        health_status TEXT,
        comments TEXT,
        updated_at TEXT NOT NULL,
        photo_url TEXT
      );

      ALTER TABLE nodes ADD COLUMN IF NOT EXISTS node_type TEXT DEFAULT 'cow';
      ALTER TABLE nodes ADD COLUMN IF NOT EXISTS static_lat DOUBLE PRECISION;
      ALTER TABLE nodes ADD COLUMN IF NOT EXISTS static_lon DOUBLE PRECISION;
      ALTER TABLE nodes ADD COLUMN IF NOT EXISTS device_id INTEGER;
      ALTER TABLE nodes ADD COLUMN IF NOT EXISTS device_key TEXT;
      ALTER TABLE nodes ADD COLUMN IF NOT EXISTS photo_url TEXT;

      CREATE TABLE IF NOT EXISTS geofences (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        geojson TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS geofence_assignments (
        geofence_id INTEGER NOT NULL REFERENCES geofences(id) ON DELETE CASCADE,
        node_id INTEGER NOT NULL REFERENCES nodes(node_id) ON DELETE CASCADE,
        PRIMARY KEY (geofence_id, node_id)
      );

      CREATE TABLE IF NOT EXISTS geofence_state (
        geofence_id INTEGER NOT NULL,
        node_id INTEGER NOT NULL,
        is_inside INTEGER NOT NULL,
        last_change_time TEXT NOT NULL,
        PRIMARY KEY (geofence_id, node_id)
      );

      CREATE TABLE IF NOT EXISTS geofence_events (
        id SERIAL PRIMARY KEY,
        geofence_id INTEGER NOT NULL,
        node_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        event_time TEXT NOT NULL,
        lat DOUBLE PRECISION,
        lon DOUBLE PRECISION
      );

      CREATE INDEX IF NOT EXISTS idx_geofence_events_time ON geofence_events(event_time);

      CREATE TABLE IF NOT EXISTS node_geofence_versions (
        node_id INTEGER PRIMARY KEY REFERENCES nodes(node_id) ON DELETE CASCADE,
        geofence_version INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS firmware_versions (
        id SERIAL PRIMARY KEY,
        version TEXT NOT NULL,
        filename_hex TEXT NOT NULL,
        filename_zip TEXT NOT NULL,
        upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        file_size INTEGER,
        checksum TEXT,
        is_active BOOLEAN DEFAULT FALSE,
        notes TEXT
      );

      CREATE TABLE IF NOT EXISTS tracker_configs (
        node_id INTEGER PRIMARY KEY REFERENCES nodes(node_id) ON DELETE CASCADE,
        config_version INTEGER DEFAULT 1,
        config_json TEXT NOT NULL,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_confirmed TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS config_push_requests (
        id SERIAL PRIMARY KEY,
        request_id TEXT UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        node_ids TEXT,
        config_json TEXT
      );

      CREATE TABLE IF NOT EXISTS config_push_status (
        request_id TEXT,
        node_id INTEGER,
        status TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        error_message TEXT,
        PRIMARY KEY (request_id, node_id)
      );

      CREATE TABLE IF NOT EXISTS node_events (
        id SERIAL PRIMARY KEY,
        node_id INTEGER NOT NULL REFERENCES nodes(node_id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        severity TEXT DEFAULT 'info',
        message TEXT,
        event_time TEXT NOT NULL,
        lat DOUBLE PRECISION,
        lon DOUBLE PRECISION
      );

      CREATE INDEX IF NOT EXISTS idx_node_events_time ON node_events(event_time);
      CREATE INDEX IF NOT EXISTS idx_node_events_node ON node_events(node_id);

      ALTER TABLE node_events ADD COLUMN IF NOT EXISTS resolved BOOLEAN DEFAULT FALSE;
      ALTER TABLE node_events ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;
      ALTER TABLE geofence_events ADD COLUMN IF NOT EXISTS resolved BOOLEAN DEFAULT FALSE;
      ALTER TABLE geofence_events ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;
    `);

    // Migration: migrate alert_resolutions data into event tables, then drop
    try {
      const arExists = await pool.query(`
        SELECT 1 FROM information_schema.tables WHERE table_name = 'alert_resolutions'
      `);
      if (arExists.rowCount > 0) {
        await pool.query(`
          UPDATE node_events SET resolved = TRUE, resolved_at = ar.resolved_at
          FROM alert_resolutions ar
          WHERE ar.alert_key = 'node_event:' || node_events.id::text AND node_events.resolved = FALSE
        `);
        await pool.query(`
          UPDATE geofence_events SET resolved = TRUE, resolved_at = ar.resolved_at
          FROM alert_resolutions ar
          WHERE ar.alert_key = 'geofence_event:' || geofence_events.id::text AND geofence_events.resolved = FALSE
        `);
        await pool.query('DROP TABLE alert_resolutions');
        debug.info('Migrated alert_resolutions into event tables and dropped table');
      }
    } catch (migErr) {
      debug.info('alert_resolutions migration skipped:', migErr.message);
    }

    // Migration: Convert device_id from BIGINT to INTEGER if needed (v3.0 upgrade)
    try {
      // Check if device_id column is still BIGINT
      const columnTypeResult = await pool.query(`
          SELECT data_type 
          FROM information_schema.columns 
          WHERE table_name = 'nodes' AND column_name = 'device_id'
        `);

      if (columnTypeResult.rows.length > 0 && columnTypeResult.rows[0].data_type === 'bigint') {
        debug.info('Migrating device_id from BIGINT to INTEGER...');

        // Create a backup of existing data
        await pool.query(`CREATE TEMP TABLE nodes_backup AS SELECT * FROM nodes`);

        // Drop and recreate the column as INTEGER
        await pool.query(`ALTER TABLE nodes DROP COLUMN device_id`);
        await pool.query(`ALTER TABLE nodes ADD COLUMN device_id INTEGER`);

        // Restore data, converting to 32-bit integer (truncate if needed)
        await pool.query(`
            UPDATE nodes 
            SET device_id = (
              SELECT CASE 
                WHEN device_id > 2147483647 THEN 2147483647  -- Max int32
                WHEN device_id < -2147483648 THEN -2147483648 -- Min int32
                ELSE device_id::INTEGER 
              END 
              FROM nodes_backup nb 
              WHERE nb.node_id = nodes.node_id
            )
            WHERE node_id IN (SELECT node_id FROM nodes_backup WHERE device_id IS NOT NULL)
          `);

        // Drop backup
        await pool.query(`DROP TABLE nodes_backup`);

        debug.info('device_id migration completed');
      }
    } catch (err) {
      debug.info('device_id migration not needed or failed:', err);
    }

    return pool;
  })();

  return poolPromise;
}

async function getDb() {
  return initDb();
}

async function withClient(fn) {
  const pool = await getDb();
  const client = await pool.connect();
  try {
    return await fn(client);
  } finally {
    client.release();
  }
}

async function ensureNodeGeofenceVersionRow(nodeId) {
  const nid = Number(nodeId);
  if (!Number.isFinite(nid)) throw new Error('invalid_node_id');
  const pool = await getDb();
  await pool.query(
    `INSERT INTO node_geofence_versions (node_id, geofence_version)
     VALUES ($1, 0)
     ON CONFLICT (node_id) DO NOTHING`,
    [nid]
  );
}

async function getNodeGeofenceVersion(nodeId) {
  const nid = Number(nodeId);
  if (!Number.isFinite(nid)) throw new Error('invalid_node_id');
  await ensureNodeGeofenceVersionRow(nid);
  const pool = await getDb();
  const res = await pool.query(
    'SELECT geofence_version as "geofenceVersion" FROM node_geofence_versions WHERE node_id = $1',
    [nid]
  );
  return Number(res.rows[0]?.geofenceVersion || 0);
}

async function bumpNodeGeofenceVersion(nodeId) {
  const nid = Number(nodeId);
  if (!Number.isFinite(nid)) throw new Error('invalid_node_id');

  return withClient(async (client) => {
    await client.query('BEGIN');
    try {
      await client.query(
        `INSERT INTO node_geofence_versions (node_id, geofence_version)
         VALUES ($1, 0)
         ON CONFLICT (node_id) DO NOTHING`,
        [nid]
      );

      const res = await client.query(
        `UPDATE node_geofence_versions
         SET geofence_version = geofence_version + 1
         WHERE node_id = $1
         RETURNING geofence_version`,
        [nid]
      );
      await client.query('COMMIT');
      return Number(res.rows[0]?.geofence_version || 0);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    }
  });
}

async function getNodeGeofencePayload(nodeId) {
  const nid = Number(nodeId);
  if (!Number.isFinite(nid)) throw new Error('invalid_node_id');

  const pool = await getDb();
  const res = await pool.query(
    `SELECT g.id as "geofenceId", g.geojson
     FROM geofence_assignments ga
     JOIN geofences g ON g.id = ga.geofence_id
     WHERE ga.node_id = $1
     ORDER BY g.id ASC
     LIMIT 1`,
    [nid]
  );
  return res.rows[0] || null;
}

async function listNodeIdsWithAnyGeofenceAssignments() {
  const pool = await getDb();
  const res = await pool.query('SELECT DISTINCT node_id as "nodeId" FROM geofence_assignments ORDER BY node_id ASC');
  return res.rows.map((r) => Number(r.nodeId)).filter((n) => Number.isFinite(n));
}

async function listNodeIdsForGeofence(geofenceId) {
  const gid = Number(geofenceId);
  if (!Number.isFinite(gid)) throw new Error('invalid_geofence_id');
  const pool = await getDb();
  const res = await pool.query(
    'SELECT node_id as "nodeId" FROM geofence_assignments WHERE geofence_id = $1 ORDER BY node_id ASC',
    [gid]
  );
  return res.rows.map((r) => Number(r.nodeId)).filter((n) => Number.isFinite(n));
}

async function getFriendlyNameMap(nodeIds) {
  if (!nodeIds.length) return {};
  const pool = await getDb();
  const rows = (await pool.query(
    'SELECT node_id as "nodeId", friendly_name as "friendlyName" FROM nodes WHERE node_id = ANY($1::int[])',
    [nodeIds.map((n) => Number(n)).filter((n) => Number.isFinite(n))]
  )).rows;
  const map = {};
  for (const r of rows) {
    if (r.friendlyName) map[String(r.nodeId)] = r.friendlyName;
  }
  return map;
}

async function getNodeInfoMap(nodeIds) {
  if (!nodeIds.length) return {};
  const pool = await getDb();
  const rows = (await pool.query(
    `SELECT node_id as "nodeId", friendly_name as "friendlyName", device_id as "deviceId", 
            node_type as "nodeType", static_lat as "staticLat", static_lon as "staticLon",
            breed, age, health_status as "healthStatus", comments, photo_url as "photoUrl"
     FROM nodes WHERE node_id = ANY($1::int[])`,
    [nodeIds.map((n) => Number(n)).filter((n) => Number.isFinite(n))]
  )).rows;
  const map = {};
  for (const r of rows) {
    map[String(r.nodeId)] = {
      friendlyName: r.friendlyName,
      deviceId: r.deviceId !== undefined && r.deviceId !== null ? Number(r.deviceId) : null,
      nodeType: r.nodeType || 'cow',
      staticLat: r.staticLat !== null ? Number(r.staticLat) : null,
      staticLon: r.staticLon !== null ? Number(r.staticLon) : null,
      breed: r.breed,
      age: r.age,
      healthStatus: r.healthStatus,
      comments: r.comments,
      photoUrl: r.photoUrl || null,
    };
  }
  return map;
}

async function upsertNodeFriendlyName(nodeId, friendlyName) {
  const now = new Date().toISOString();
  const pool = await getDb();
  await pool.query(
    `INSERT INTO nodes (node_id, friendly_name, updated_at)
     VALUES ($1, $2, $3)
     ON CONFLICT (node_id) DO UPDATE SET friendly_name = EXCLUDED.friendly_name, updated_at = EXCLUDED.updated_at`,
    [Number(nodeId), String(friendlyName), now]
  );
}

async function upsertNodeInfo(nodeId, { friendlyName, nodeType, staticLat, staticLon, breed, age, healthStatus, comments, photoUrl }) {
  const now = new Date().toISOString();
  const pool = await getDb();
  await pool.query(
    `INSERT INTO nodes (node_id, friendly_name, node_type, static_lat, static_lon, breed, age, health_status, comments, photo_url, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     ON CONFLICT (node_id) DO UPDATE SET
       friendly_name = COALESCE(EXCLUDED.friendly_name, nodes.friendly_name),
       node_type = COALESCE(EXCLUDED.node_type, nodes.node_type),
       static_lat = COALESCE(EXCLUDED.static_lat, nodes.static_lat),
       static_lon = COALESCE(EXCLUDED.static_lon, nodes.static_lon),
       breed = COALESCE(EXCLUDED.breed, nodes.breed),
       age = COALESCE(EXCLUDED.age, nodes.age),
       health_status = COALESCE(EXCLUDED.health_status, nodes.health_status),
       comments = COALESCE(EXCLUDED.comments, nodes.comments),
       photo_url = COALESCE(EXCLUDED.photo_url, nodes.photo_url),
       updated_at = EXCLUDED.updated_at`,
    [
      Number(nodeId),
      friendlyName ? String(friendlyName) : null,
      nodeType ? String(nodeType) : null,
      staticLat !== undefined && staticLat !== null ? Number(staticLat) : null,
      staticLon !== undefined && staticLon !== null ? Number(staticLon) : null,
      breed ? String(breed) : null,
      age !== undefined && age !== null ? Number(age) : null,
      healthStatus ? String(healthStatus) : null,
      comments ? String(comments) : null,
      photoUrl !== undefined && photoUrl !== null ? String(photoUrl) : null,
      now,
    ]
  );
}

async function updateNodePhotoUrl(nodeId, photoUrl) {
  const now = new Date().toISOString();
  const pool = await getDb();
  await pool.query(
    `UPDATE nodes SET photo_url = $2, updated_at = $3 WHERE node_id = $1`,
    [Number(nodeId), photoUrl ? String(photoUrl) : null, now]
  );
}

async function listNodes() {
  const pool = await getDb();
  return (await pool.query(`
    SELECT node_id as "nodeId",
           friendly_name as "friendlyName",
           device_id as "deviceId",
           node_type as "nodeType",
           static_lat as "staticLat",
           static_lon as "staticLon",
           breed,
           age,
           health_status as "healthStatus",
           comments,
           photo_url as "photoUrl",
           updated_at as "updatedAt"
    FROM nodes
    ORDER BY node_id ASC
  `)).rows;
}

async function getNextAvailableNodeId() {
  const pool = await getDb();
  // Find the first available node_id from 1-255 that's not in use
  const result = await pool.query(`
    WITH used_ids AS (
      SELECT node_id FROM nodes WHERE node_id BETWEEN 1 AND 255
    ),
    all_ids AS (
      SELECT generate_series(1, 255) as node_id
    )
    SELECT node_id as "nodeId"
    FROM all_ids
    WHERE node_id NOT IN (SELECT node_id FROM used_ids)
    ORDER BY node_id ASC
    LIMIT 1
  `);

  if (result.rows.length === 0) {
    throw new Error('no_available_node_ids');
  }

  return Number(result.rows[0].nodeId);
}

async function setNodeDeviceCredentials(nodeId, { deviceId, deviceKey }) {
  const nid = Number(nodeId);
  if (!Number.isFinite(nid)) throw new Error('invalid_node_id');
  const did = deviceId !== undefined && deviceId !== null ? Number(deviceId) : null;
  if (did !== null && !Number.isFinite(did)) throw new Error('invalid_device_id');
  if (did !== null && (did < 0 || did > 4294967295)) throw new Error('device_id_out_of_range'); // uint32_t range
  const key = deviceKey !== undefined && deviceKey !== null ? String(deviceKey) : null;
  const now = new Date().toISOString();
  const pool = await getDb();
  await pool.query(
    `INSERT INTO nodes (node_id, device_id, device_key, updated_at)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (node_id) DO UPDATE SET
       device_id = EXCLUDED.device_id,
       device_key = EXCLUDED.device_key,
       updated_at = EXCLUDED.updated_at`,
    [nid, did, key, now]
  );
}

async function listNodeDeviceCredentials() {
  const pool = await getDb();
  return (await pool.query(
    `SELECT node_id as "nodeId", device_id as "deviceId", device_key as "deviceKey"
     FROM nodes
     WHERE device_id IS NOT NULL AND device_key IS NOT NULL
     ORDER BY node_id ASC`
  )).rows;
}

async function createGeofence(name, geojson) {
  const now = new Date().toISOString();
  const pool = await getDb();
  const result = await pool.query(
    `INSERT INTO geofences (name, geojson, created_at, updated_at) VALUES ($1, $2, $3, $4) RETURNING id`,
    [String(name), String(geojson), now, now]
  );
  return result.rows[0].id;
}

async function updateGeofence(id, { name, geojson }) {
  const now = new Date().toISOString();
  const pool = await getDb();
  const existing = await pool.query('SELECT id FROM geofences WHERE id = $1', [Number(id)]);
  if (existing.rowCount === 0) return false;

  const updates = [];
  const params = [];
  let i = 1;
  if (name !== undefined) {
    updates.push(`name = $${i++}`);
    params.push(String(name));
  }
  if (geojson !== undefined) {
    updates.push(`geojson = $${i++}`);
    params.push(String(geojson));
  }
  updates.push(`updated_at = $${i++}`);
  params.push(now);
  params.push(Number(id));

  await pool.query(`UPDATE geofences SET ${updates.join(', ')} WHERE id = $${i}`, params);
  return true;
}

async function deleteGeofence(id) {
  const pool = await getDb();
  await pool.query('DELETE FROM geofences WHERE id = $1', [Number(id)]);
}

async function listGeofences() {
  const pool = await getDb();
  const fences = (await pool.query(`
    SELECT g.id,
           g.name,
           g.geojson,
           g.created_at as "createdAt",
           g.updated_at as "updatedAt",
           COALESCE(ARRAY_AGG(ga.node_id ORDER BY ga.node_id) FILTER (WHERE ga.node_id IS NOT NULL), '{}') as "nodeIds"
    FROM geofences g
    LEFT JOIN geofence_assignments ga ON ga.geofence_id = g.id
    GROUP BY g.id
    ORDER BY g.id DESC
  `)).rows;
  // Ensure nodeIds is a plain JS array of numbers
  for (const f of fences) {
    f.nodeIds = Array.isArray(f.nodeIds) ? f.nodeIds.map((n) => Number(n)) : [];
  }
  return fences;
}

async function setGeofenceNodes(geofenceId, nodeIds) {
  const gid = Number(geofenceId);

  const unique = Array.from(new Set((nodeIds || []).map((n) => Number(n)).filter((n) => Number.isFinite(n))));

  // Ensure node rows exist before attempting to insert into geofence_assignments.
  // Doing this outside the assignment transaction avoids FK issues if the database
  // is enforcing constraints against committed parent rows.
  if (unique.length) {
    const pool = await getDb();
    const now = new Date().toISOString();

    // First verify which nodes already exist
    const existingRes = await pool.query(
      'SELECT node_id FROM nodes WHERE node_id = ANY($1::int[])',
      [unique]
    );
    const existingIds = new Set(existingRes.rows.map(r => Number(r.node_id)));
    const missingIds = unique.filter(id => !existingIds.has(id));

    // Insert missing nodes individually to ensure they exist
    for (const nodeId of missingIds) {
      await pool.query(
        `INSERT INTO nodes (node_id, friendly_name, updated_at)
         VALUES ($1, NULL, $2)
         ON CONFLICT (node_id) DO NOTHING`,
        [nodeId, now]
      );
    }

    // Update existing nodes
    if (existingIds.size > 0) {
      await pool.query(
        `UPDATE nodes SET updated_at = $2 WHERE node_id = ANY($1::int[])`,
        [Array.from(existingIds), now]
      );
    }
  }

  await withClient(async (client) => {
    await client.query('BEGIN');
    try {
      await client.query('DELETE FROM geofence_assignments WHERE geofence_id = $1', [gid]);

      if (unique.length) {
        // Verify nodes exist before inserting assignments
        const verifyRes = await client.query(
          'SELECT node_id FROM nodes WHERE node_id = ANY($1::int[])',
          [unique]
        );
        const foundIds = new Set(verifyRes.rows.map(r => Number(r.node_id)));
        const stillMissing = unique.filter(id => !foundIds.has(id));

        if (stillMissing.length > 0) {
          throw new Error(`Nodes still missing after upsert: ${stillMissing.join(', ')}`);
        }

        await client.query(
          `INSERT INTO geofence_assignments (geofence_id, node_id)
           SELECT $1, node_id
           FROM UNNEST($2::int[]) AS node_id
           ON CONFLICT DO NOTHING`,
          [gid, unique]
        );
      }

      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    }
  });
}

async function getAssignedGeofencesForNodeIds(nodeIds) {
  if (!nodeIds.length) return {};
  const pool = await getDb();
  const ids = nodeIds.map((n) => Number(n)).filter((n) => Number.isFinite(n));
  const rows = (await pool.query(
    `SELECT ga.node_id as "nodeId", g.id as "geofenceId", g.name as name, g.geojson as geojson
     FROM geofence_assignments ga
     JOIN geofences g ON g.id = ga.geofence_id
     WHERE ga.node_id = ANY($1::int[])
     ORDER BY ga.node_id ASC, g.id ASC`,
    [ids]
  )).rows;
  const map = {};
  for (const r of rows) {
    const key = String(r.nodeId);
    if (!map[key]) map[key] = [];
    map[key].push({ id: r.geofenceId, name: r.name, geojson: r.geojson });
  }
  return map;
}

async function getGeofenceState(geofenceId, nodeId) {
  const pool = await getDb();
  const res = await pool.query(
    `SELECT is_inside as "isInside", last_change_time as "lastChangeTime"
     FROM geofence_state
     WHERE geofence_id = $1 AND node_id = $2`,
    [Number(geofenceId), Number(nodeId)]
  );
  return res.rows[0];
}

async function setGeofenceState(geofenceId, nodeId, isInside, time) {
  const pool = await getDb();
  await pool.query(
    `INSERT INTO geofence_state (geofence_id, node_id, is_inside, last_change_time)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (geofence_id, node_id)
     DO UPDATE SET is_inside = EXCLUDED.is_inside, last_change_time = EXCLUDED.last_change_time`,
    [Number(geofenceId), Number(nodeId), isInside ? 1 : 0, String(time)]
  );
}

async function insertGeofenceEvent({ geofenceId, nodeId, type, eventTime, lat, lon }) {
  const pool = await getDb();
  const result = await pool.query(
    `INSERT INTO geofence_events (geofence_id, node_id, type, event_time, lat, lon)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id`,
    [Number(geofenceId), Number(nodeId), String(type), String(eventTime), lat ?? null, lon ?? null]
  );
  return result.rows[0].id;
}

async function listGeofenceEvents({ limit, since, nodeId }) {
  const pool = await getDb();
  let query = `
    SELECT e.id, e.geofence_id as "geofenceId", f.name as "geofenceName",
           e.node_id as "nodeId", n.friendly_name as "nodeName",
           e.type, e.event_time as "eventTime", e.lat, e.lon,
           e.resolved, e.resolved_at as "resolvedAt"
    FROM geofence_events e
    JOIN geofences f ON e.geofence_id = f.id
    JOIN nodes n ON e.node_id = n.node_id
  `;
  const params = [];
  const clauses = [];

  if (nodeId) {
    params.push(nodeId);
    clauses.push(`e.node_id = $${params.length}`);
  }
  if (since) {
    params.push(since);
    clauses.push(`e.event_time >= $${params.length}`);
  }

  if (clauses.length) {
    query += ` WHERE ` + clauses.join(' AND ');
  }

  query += ` ORDER BY e.event_time DESC LIMIT $${params.length + 1}`;
  params.push(limit || 50);

  return (await pool.query(query, params)).rows;
}

async function insertNodeEvent({ nodeId, type, severity = 'info', message, eventTime, lat, lon }) {
  const pool = await getDb();
  const now = new Date().toISOString();
  const res = await pool.query(
    `INSERT INTO node_events (node_id, type, severity, message, event_time, lat, lon)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id`,
    [nodeId, type, severity, message, eventTime || now, lat, lon]
  );
  return res.rows[0].id;
}

async function listNodeEvents({ nodeId, limit = 50, since }) {
  const pool = await getDb();
  let query = `
    SELECT e.id, e.node_id as "nodeId", n.friendly_name as "nodeName",
           e.type, e.severity, e.message, e.event_time as "eventTime", e.lat, e.lon,
           e.resolved, e.resolved_at as "resolvedAt"
    FROM node_events e
    JOIN nodes n ON e.node_id = n.node_id
  `;
  const params = [];
  const clauses = [];

  if (nodeId) {
    params.push(nodeId);
    clauses.push(`e.node_id = $${params.length}`);
  }
  if (since) {
    params.push(since);
    clauses.push(`e.event_time >= $${params.length}`);
  }

  if (clauses.length) {
    query += ` WHERE ` + clauses.join(' AND ');
  }

  query += ` ORDER BY e.event_time DESC LIMIT $${params.length + 1}`;
  params.push(limit);

  return (await pool.query(query, params)).rows;
}

async function ensureNodesExist(nodeIds) {
  if (!nodeIds || !nodeIds.length) return;
  const pool = await getDb();
  const now = new Date().toISOString();
  const unique = Array.from(new Set(nodeIds.map((n) => Number(n)).filter((n) => Number.isFinite(n))));

  debug.info('ensureNodesExist: processing nodeIds', { nodeIds: unique });

  // Check existing nodes first
  const existingRes = await pool.query(
    'SELECT node_id FROM nodes WHERE node_id = ANY($1::int[])',
    [unique]
  );
  const existingIds = new Set(existingRes.rows.map(r => Number(r.node_id)));
  const missingIds = unique.filter(id => !existingIds.has(id));

  debug.info('ensureNodesExist: existing nodes', { existing: Array.from(existingIds), missing: missingIds });

  if (missingIds.length > 0) {
    debug.info('ensureNodesExist: inserting missing nodes', { missingIds });
    for (const nodeId of missingIds) {
      await pool.query(
        `INSERT INTO nodes (node_id, friendly_name, updated_at)
         VALUES ($1, NULL, $2)
         ON CONFLICT (node_id) DO NOTHING`,
        [nodeId, now]
      );
    }
    debug.info('ensureNodesExist: inserted nodes', { count: missingIds.length });
  } else {
    debug.info('ensureNodesExist: all nodes already exist', { nodeIds: unique });
  }
}

// Firmware management functions
async function createFirmwareVersion(version, filenameHex, filenameZip, fileSize, checksum, notes) {
  const pool = await getDb();
  const res = await pool.query(
    `INSERT INTO firmware_versions (version, filename_hex, filename_zip, file_size, checksum, notes)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id`,
    [version, filenameHex, filenameZip, fileSize, checksum, notes]
  );
  return res.rows[0].id;
}

async function listFirmwareVersions() {
  const pool = await getDb();
  const res = await pool.query(
    `SELECT id, version, filename_hex, filename_zip, upload_date, file_size, checksum, is_active, notes
     FROM firmware_versions
     ORDER BY upload_date DESC`
  );
  return res.rows;
}

async function getFirmwareVersion(id) {
  const pool = await getDb();
  const res = await pool.query(
    `SELECT id, version, filename_hex, filename_zip, upload_date, file_size, checksum, is_active, notes
     FROM firmware_versions
     WHERE id = $1`,
    [id]
  );
  return res.rows[0];
}

async function setActiveFirmware(id) {
  const pool = await getDb();
  await pool.query('UPDATE firmware_versions SET is_active = FALSE');
  await pool.query('UPDATE firmware_versions SET is_active = TRUE WHERE id = $1', [id]);
}

async function deleteFirmwareVersion(id) {
  const pool = await getDb();
  await pool.query('DELETE FROM firmware_versions WHERE id = $1', [id]);
}

async function cleanupOldFirmware(keepCount = 5) {
  const pool = await getDb();
  const res = await pool.query(
    `SELECT id FROM firmware_versions ORDER BY upload_date DESC OFFSET $1`,
    [keepCount]
  );
  for (const row of res.rows) {
    await pool.query('DELETE FROM firmware_versions WHERE id = $1', [row.id]);
  }
  return res.rows.length;
}

// Config management functions
async function saveTrackerConfig(nodeId, configJson, version) {
  const pool = await getDb();
  await pool.query(
    `INSERT INTO tracker_configs (node_id, config_json, config_version, last_updated)
     VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
     ON CONFLICT (node_id) DO UPDATE
     SET config_json = $2, config_version = $3, last_updated = CURRENT_TIMESTAMP`,
    [nodeId, configJson, version]
  );
}

async function getTrackerConfig(nodeId) {
  const pool = await getDb();
  const res = await pool.query(
    `SELECT node_id, config_json, config_version, last_updated, last_confirmed
     FROM tracker_configs
     WHERE node_id = $1`,
    [nodeId]
  );
  return res.rows[0];
}

async function incrementConfigVersion(nodeId) {
  const pool = await getDb();
  const res = await pool.query(
    `INSERT INTO tracker_configs (node_id, config_json, config_version)
     VALUES ($1, '{}', 1)
     ON CONFLICT (node_id) DO UPDATE
     SET config_version = tracker_configs.config_version + 1
     RETURNING config_version`,
    [nodeId]
  );
  return res.rows[0].config_version;
}

async function createConfigPushRequest(requestId, nodeIds, configJson) {
  const pool = await getDb();
  await pool.query(
    `INSERT INTO config_push_requests (request_id, node_ids, config_json)
     VALUES ($1, $2, $3)`,
    [requestId, JSON.stringify(nodeIds), configJson]
  );
}

async function updateConfigPushStatus(requestId, nodeId, status, errorMessage = null) {
  const pool = await getDb();
  await pool.query(
    `INSERT INTO config_push_status (request_id, node_id, status, error_message, updated_at)
     VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
     ON CONFLICT (request_id, node_id) DO UPDATE
     SET status = $3, error_message = $4, updated_at = CURRENT_TIMESTAMP`,
    [requestId, nodeId, status, errorMessage]
  );
}

async function getConfigPushStatus(requestId) {
  const pool = await getDb();
  const res = await pool.query(
    `SELECT node_id, status, updated_at, error_message
     FROM config_push_status
     WHERE request_id = $1
     ORDER BY node_id`,
    [requestId]
  );
  return res.rows;
}

// Alert resolution functions — resolve by updating event rows directly
async function resolveAlert(alertKey) {
  const pool = await getDb();
  if (alertKey.startsWith('node_event:')) {
    const id = Number(alertKey.split(':')[1]);
    if (Number.isFinite(id)) {
      await pool.query('UPDATE node_events SET resolved = TRUE, resolved_at = NOW() WHERE id = $1', [id]);
    }
  } else if (alertKey.startsWith('geofence_event:')) {
    const id = Number(alertKey.split(':')[1]);
    if (Number.isFinite(id)) {
      await pool.query('UPDATE geofence_events SET resolved = TRUE, resolved_at = NOW() WHERE id = $1', [id]);
    }
  }
}

async function cleanupOldResolvedEvents(daysOld = 90) {
  const pool = await getDb();
  const r1 = await pool.query(`DELETE FROM node_events WHERE resolved = TRUE AND resolved_at < NOW() - INTERVAL '${Math.floor(daysOld)} days'`);
  const r2 = await pool.query(`DELETE FROM geofence_events WHERE resolved = TRUE AND resolved_at < NOW() - INTERVAL '${Math.floor(daysOld)} days'`);
  return (r1.rowCount || 0) + (r2.rowCount || 0);
}

module.exports = {
  initDb,
  getDb,
  getFriendlyNameMap,
  getNodeInfoMap,
  upsertNodeFriendlyName,
  upsertNodeInfo,
  updateNodePhotoUrl,
  listNodes,
  getNextAvailableNodeId,
  setNodeDeviceCredentials,
  listNodeDeviceCredentials,
  ensureNodesExist,
  createGeofence,
  updateGeofence,
  deleteGeofence,
  listGeofences,
  setGeofenceNodes,
  getAssignedGeofencesForNodeIds,
  getGeofenceState,
  setGeofenceState,
  insertGeofenceEvent,
  listGeofenceEvents,
  insertNodeEvent,
  listNodeEvents,
  ensureNodeGeofenceVersionRow,
  getNodeGeofenceVersion,
  bumpNodeGeofenceVersion,
  getNodeGeofencePayload,
  listNodeIdsWithAnyGeofenceAssignments,
  listNodeIdsForGeofence,
  createFirmwareVersion,
  listFirmwareVersions,
  getFirmwareVersion,
  setActiveFirmware,
  deleteFirmwareVersion,
  cleanupOldFirmware,
  saveTrackerConfig,
  getTrackerConfig,
  incrementConfigVersion,
  createConfigPushRequest,
  updateConfigPushStatus,
  getConfigPushStatus,
  resolveAlert,
  cleanupOldResolvedEvents,
};
