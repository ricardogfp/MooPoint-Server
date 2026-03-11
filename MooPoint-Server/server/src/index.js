require('dotenv').config();

const http = require('http');
const path = require('path');
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const cookieParser = require('cookie-parser');
const session = require('express-session');
const multer = require('multer');

const { logger, LOG_FILE, setLogLevel } = require('./logger');
const { checkInfluxHealth, getLatestNodes, getNodeById, getNodeHistory, getBehaviorData, getBehaviorSummary, getNodeTrackingAge, getFenceHistory } = require('./influx');
const db = require('./db');
const { parseGeoJsonPolygon, runGeofenceExitCheck } = require('./geofence');
const { createWsServer } = require('./ws');
const { createMqttGeofenceSync } = require('./mqtt_geofence_sync');
const { createMqttDeviceMapSync } = require('./mqtt_device_map_sync');
const { createMqttTrackerSubscriber } = require('./mqtt_tracker_subscriber');
const { createMqttFenceSubscriber } = require('./mqtt_fence_subscriber');
const AIDevAnalytics = require('./ai_dev_analytics');
const firmwareManager = require('./firmware_manager');
const mqttConfigPush = require('./mqtt_config_push');

// MQTT client for BLE locate requests (shared with other sync modules)
let mqttClient = null;
let mqttLocateTopic = null;

const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');

const app = express();
app.disable('x-powered-by');

app.set('trust proxy', 1);
const ALLOWED_ORIGINS = (process.env.CORS_ORIGINS || 'https://loracow.daeron16.com').split(',').map((o) => o.trim());
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.includes(origin)) return cb(null, true);
    cb(new Error('Not allowed by CORS'));
  },
  credentials: true,
}));
app.use(express.json({ limit: '1mb' }));
app.use(cookieParser());

// --- Cow photo uploads ---
const uploadsDir = path.join(__dirname, '..', 'uploads', 'photos');
fs.mkdirSync(uploadsDir, { recursive: true });

// Serve uploaded files with proper CORS and cache headers
app.use('/uploads', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  res.setHeader('Cache-Control', 'public, max-age=86400'); // 24 hours
  next();
}, express.static(path.join(__dirname, '..', 'uploads')));

// API route alias for photos (for Cloudflare tunnel compatibility)
app.get('/api/uploads/photos/:filename', (req, res) => {
  const filename = req.params.filename;
  const filePath = path.join(uploadsDir, filename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'photo_not_found' });
  }

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cache-Control', 'public, max-age=86400');
  res.sendFile(filePath);
});

// --- Firmware uploads ---
const firmwareUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, firmwareManager.FIRMWARE_DIR),
    filename: (_req, file, cb) => {
      const timestamp = Date.now();
      const ext = path.extname(file.originalname) || '.hex';
      cb(null, `firmware_${timestamp}${ext}`);
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'application/octet-stream' || file.originalname.endsWith('.hex')) {
      cb(null, true);
    } else {
      cb(new Error('Only .hex files are allowed'));
    }
  },
});

const photoStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `node_${req.params.nodeId}_${Date.now()}${ext}`);
  },
});
const photoUpload = multer({
  storage: photoStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
  fileFilter: (_req, file, cb) => {
    if (/^image\/(jpeg|png|webp|gif)$/.test(file.mimetype)) cb(null, true);
    else cb(new Error('Only JPEG, PNG, WebP and GIF images are allowed'));
  },
});

const sessionSecret = process.env.SESSION_SECRET || 'change-me';
const sessionParser = session({
  secret: sessionSecret,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    sameSite: 'lax',
    secure: false, // Allow cookies over HTTP (Cloudflare handles HTTPS)
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
  },
});
// Middleware to clear stale session cookies BEFORE session parser
app.use((req, res, next) => {
  const cookieHeader = req.headers.cookie;
  if (cookieHeader) {
    const sidCookies = cookieHeader.match(/connect\.sid=[^;]+/g);
    if (sidCookies && sidCookies.length > 1) {
      logger.info('Multiple session cookies detected, clearing all stale cookies', {
        cookieCount: sidCookies.length
      });
      // Clear all connect.sid cookies by setting expired cookies with proper attributes
      res.clearCookie('connect.sid', { path: '/', httpOnly: true, sameSite: 'lax' });
    }
  }
  next();
});

app.use(sessionParser);

// Warn if admin password is stored as plaintext
if (process.env.ADMIN_PASSWORD && !process.env.ADMIN_PASSWORD.startsWith('$2b$')) {
  logger.warn('ADMIN_PASSWORD is plaintext. Hash it with bcryptjs for security.');
}

// Simple test endpoint without authentication for tunnel debugging
app.get('/test-tunnel', (req, res) => {
  res.json({
    message: 'Tunnel is working!',
    timestamp: new Date().toISOString(),
    headers: req.headers,
    host: req.get('host'),
    protocol: req.protocol
  });
});

// API prefixed test endpoint
app.get('/api/test-tunnel', (req, res) => {
  res.json({
    message: 'API tunnel is working!',
    timestamp: new Date().toISOString(),
    headers: req.headers,
    host: req.get('host'),
    protocol: req.protocol
  });
});

// Test endpoint to check uploads directory
app.get('/admin/uploads-test', requireAuth, async (req, res) => {
  try {
    const uploadsPath = path.join(__dirname, '..', 'uploads');
    const photosPath = path.join(uploadsPath, 'photos');

    // Check if directories exist
    const uploadsExists = fs.existsSync(uploadsPath);
    const photosExists = fs.existsSync(photosPath);

    // List files in photos directory
    let photoFiles = [];
    if (photosExists) {
      photoFiles = fs.readdirSync(photosPath);
    }

    logger.info('Uploads directory test', {
      uploadsPath,
      photosPath,
      uploadsExists,
      photosExists,
      photoFiles: photoFiles.slice(0, 10) // Show first 10 files
    });

    res.json({
      uploadsPath,
      photosPath,
      uploadsExists,
      photosExists,
      photoFiles,
      photoCount: photoFiles.length
    });
  } catch (err) {
    logger.error('Uploads test failed', { err: err.message || err });
    res.status(500).json({ error: 'failed_to_test_uploads' });
  }
});

app.get('/api/photos-list', requireAuth, (req, res) => {
  try {
    const photosPath = path.join(__dirname, '..', 'uploads', 'photos');

    if (!fs.existsSync(photosPath)) {
      return res.json({ error: 'photos_directory_not_found', photosPath });
    }

    const photoFiles = fs.readdirSync(photosPath);
    const photoDetails = photoFiles.map(filename => {
      const filePath = path.join(photosPath, filename);
      const stats = fs.statSync(filePath);
      return {
        filename,
        size: stats.size,
        created: stats.birthtime || stats.mtime,
        url: `https://api.loracow.daeron16.com/uploads/photos/${filename}`
      };
    });

    res.json({
      photosPath,
      photoCount: photoFiles.length,
      photos: photoDetails
    });
  } catch (err) {
    res.status(500).json({ error: 'failed_to_list_photos', message: err.message });
  }
});

// API prefixed uploads-test endpoint
app.get('/api/admin/uploads-test', requireAuth, async (req, res) => {
  try {
    const uploadsPath = path.join(__dirname, '..', 'uploads');
    const photosPath = path.join(uploadsPath, 'photos');

    // Check if directories exist
    const uploadsExists = fs.existsSync(uploadsPath);
    const photosExists = fs.existsSync(photosPath);

    // List files in photos directory
    let photoFiles = [];
    if (photosExists) {
      photoFiles = fs.readdirSync(photosPath);
    }

    logger.info('API Uploads directory test', {
      uploadsPath,
      photosPath,
      uploadsExists,
      photosExists,
      photoFiles: photoFiles.slice(0, 10) // Show first 10 files
    });

    res.json({
      uploadsPath,
      photosPath,
      uploadsExists,
      photosExists,
      photoFiles,
      photoCount: photoFiles.length
    });
  } catch (err) {
    logger.error('API Uploads test failed', { err: err.message || err });
    res.status(500).json({ error: 'failed_to_test_uploads' });
  }
});

function serializeError(err) {
  if (!err) return err;
  if (err instanceof Error) {
    return {
      name: err.name,
      message: err.message,
      stack: err.stack,
      code: err.code,
      detail: err.detail,
      severity: err.severity,
    };
  }
  return err;
}

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const ms = Date.now() - start;
    logger.info('HTTP request', {
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      ms
    });
  });
  next();
});

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.get('/health/influx', async (req, res) => {
  const result = await checkInfluxHealth();
  res.status(result.ok ? 200 : 503).json({ ok: result.ok, status: result.status, body: result.body });
});

// BLE locate endpoint
app.post('/api/ble_locate', requireAuth, async (req, res) => {
  const nodeId = Number(req.body?.node_id);
  const minutes = Number(req.body?.minutes) || 5;

  if (!Number.isFinite(nodeId) || nodeId <= 0 || nodeId > 255) {
    return res.status(400).json({ error: 'invalid_node_id' });
  }
  if (!Number.isFinite(minutes) || minutes < 1 || minutes > 60) {
    return res.status(400).json({ error: 'invalid_minutes' });
  }

  const payload = JSON.stringify({ node_id: nodeId, minutes });

  if (!mqttClient || !mqttClient.connected) {
    logger.error('MQTT client not connected for BLE locate', { nodeId, minutes });
    return res.status(503).json({ error: 'mqtt_unavailable' });
  }

  try {
    const startTime = Date.now();
    const payloadSize = Buffer.byteLength(payload, 'utf8');

    await new Promise((resolve, reject) => {
      mqttClient.publish(mqttLocateTopic, payload, { qos: 1 }, (err) => {
        const duration = Date.now() - startTime;
        if (err) {
          logger.error('BLE locate MQTT publish failed', {
            duration,
            payloadSize,
            topic: mqttLocateTopic,
            qos: 1,
            nodeId,
            minutes,
            err: serializeError(err)
          });
          return reject(err);
        }
        logger.info('BLE locate MQTT publish success', {
          duration,
          payloadSize,
          topic: mqttLocateTopic,
          qos: 1,
          nodeId,
          minutes
        });
        resolve();
      });
    });
    res.status(202).json({ ok: true, nodeId, minutes });
  } catch (err) {
    logger.error('Failed to publish BLE locate MQTT', { nodeId, minutes, err: serializeError(err) });
    res.status(500).json({ error: 'mqtt_publish_failed' });
  }
});

app.get('/auth/me', (req, res) => {
  // Debug session details
  logger.info('Auth/me check', {
    hasSession: !!req.session,
    sessionId: req.session?.id,
    user: req.session?.user,
    cookie: req.headers.cookie
  });

  if (req.session?.user?.username) {
    return res.json({ authenticated: true, username: req.session.user.username });
  }

  // If session exists but no user, regenerate to clear stale session
  if (req.session) {
    req.session.regenerate(() => {
      return res.status(401).json({ authenticated: false });
    });
  } else {
    return res.status(401).json({ authenticated: false });
  }
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_attempts' },
});

app.post('/auth/login', loginLimiter, async (req, res) => {
  const adminUser = process.env.ADMIN_USERNAME;
  const adminPass = process.env.ADMIN_PASSWORD;
  if (!adminUser || !adminPass) {
    return res.status(403).json({ error: 'admin_disabled' });
  }

  const username = String(req.body?.username || '').trim();
  const password = String(req.body?.password || '');
  if (!username || !password) {
    return res.status(400).json({ error: 'credentials_required' });
  }

  if (username !== adminUser) {
    return res.status(401).json({ error: 'invalid_credentials' });
  }

  // Support both bcrypt hashes ($2b$...) and legacy plaintext passwords
  const match = adminPass.startsWith('$2b$')
    ? await bcrypt.compare(password, adminPass)
    : password === adminPass;

  if (!match) {
    return res.status(401).json({ error: 'invalid_credentials' });
  }

  // Regenerate session to clear any old stale cookies
  req.session.regenerate((err) => {
    if (err) {
      logger.error('Session regenerate failed', { err });
      return res.status(500).json({ error: 'session_error' });
    }

    req.session.user = { username };

    logger.info('Login successful', { username, sessionId: req.session.id });

    res.json({ ok: true, username });
  });
});

app.post('/auth/logout', (req, res) => {
  req.session.destroy(() => {
    res.json({ ok: true });
  });
});

app.get('/api/nodes/events', requireAuth, async (req, res) => {
  const nodeId = req.query.nodeId ? Number(req.query.nodeId) : null;
  const limit = Math.min(Number(req.query.limit || '50'), 500);
  try {
    const events = await db.listNodeEvents({ nodeId, limit });
    res.json(events);
  } catch (err) {
    logger.error('GET /api/nodes/events failed', { err });
    res.status(500).json({ error: 'failed_to_query_events' });
  }
});

app.get('/api/nodes', requireAuth, async (req, res) => {
  try {
    const nodes0 = await getLatestNodes();
    const nodeIds = nodes0.map((c) => c.nodeId);
    logger.info('GET /api/nodes: discovered nodeIds', { nodeIds });
    await db.ensureNodesExist(nodeIds);
    const nodes = await applyFriendlyNames(nodes0);
    await runGeofenceChecksForNodes(nodes, () => { });
    res.json(nodes);
  } catch (err) {
    logger.error('GET /api/nodes failed', { err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_query_influx' });
  }
});

// Alias for transition
app.get('/api/cows', (req, res) => res.redirect('/api/nodes'));
app.get('/nodejs/api/cows', (req, res) => res.redirect('/api/nodes'));

// Alias for Flutter web compatibility
app.get('/nodejs/api/nodes', requireAuth, async (req, res) => {
  try {
    const nodes0 = await getLatestNodes();
    const nodeIds = nodes0.map((c) => c.nodeId);
    logger.info('GET /nodejs/api/nodes: discovered nodeIds', { nodeIds });
    await db.ensureNodesExist(nodeIds);
    const nodes = await applyFriendlyNames(nodes0);
    await runGeofenceChecksForNodes(nodes, () => { });
    res.json(nodes);
  } catch (err) {
    logger.error('GET /nodejs/api/nodes failed', { err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_query_influx' });
  }
});

app.put('/admin/nodes/:nodeId/device-credentials', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const deviceId = req.body?.deviceId;
  const deviceKey = req.body?.deviceKey;

  if (deviceId === undefined || deviceId === null) {
    return res.status(400).json({ error: 'device_id_required' });
  }
  if (deviceKey === undefined || deviceKey === null) {
    return res.status(400).json({ error: 'device_key_required' });
  }

  const did = Number(deviceId);
  if (!Number.isFinite(did)) {
    return res.status(400).json({ error: 'invalid_device_id' });
  }
  if (did < 0 || did > 4294967295) { // uint32_t range
    return res.status(400).json({ error: 'device_id_out_of_range' });
  }

  const key = String(deviceKey).trim();
  if (!/^[0-9a-fA-F]{32,128}$/.test(key)) {
    return res.status(400).json({ error: 'invalid_device_key' });
  }

  try {
    await db.setNodeDeviceCredentials(nodeId, { deviceId: did, deviceKey: key.toLowerCase() });
    if (mqttDeviceMapSync) {
      const gatewayIds = mqttDeviceMapSync.parseGatewayIdsFromEnv();
      if (gatewayIds.length) {
        mqttDeviceMapSync.publishDeviceMapForGateways(gatewayIds).catch((err) => {
          logger.error('device_map republish after credential update failed', { err: serializeError(err) });
        });
      }
    }
    res.json({ ok: true });
  } catch (err) {
    logger.error('PUT /admin/nodes/:nodeId/device-credentials failed', { nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_set_device_credentials' });
  }
});

app.post('/admin/gateways/:gatewayId/device-map/publish', requireAuth, async (req, res) => {
  const { gatewayId } = req.params;
  if (!mqttDeviceMapSync) {
    return res.status(503).json({ error: 'mqtt_device_map_sync_not_ready' });
  }
  try {
    const result = await mqttDeviceMapSync.publishDeviceMapForGateway(gatewayId, { retain: true });
    res.json({ ok: true, ...result });
  } catch (err) {
    logger.error('POST /admin/gateways/:gatewayId/device-map/publish failed', { gatewayId, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_publish_device_map' });
  }
});

app.get('/admin/device-credentials', requireAuth, async (req, res) => {
  try {
    const rows = await db.listNodeDeviceCredentials();
    const normalized = rows.map((r) => ({
      nodeId: Number(r.nodeId),
      deviceId: r.deviceId !== undefined && r.deviceId !== null ? Number(r.deviceId) : null,
      deviceKey: r.deviceKey ? String(r.deviceKey) : null,
    }));
    res.json(normalized);
  } catch (err) {
    logger.error('GET /admin/device-credentials failed', { err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_list_device_credentials' });
  }
});

app.get('/api/nodes/:nodeId', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  try {
    const node0 = await getNodeById(nodeId);
    const nodes = await applyFriendlyNames(node0 ? [node0] : []);
    const node = nodes[0] || null;

    if (!node) {
      return res.status(404).json({ error: 'node_not_found' });
    }
    res.json(node);
  } catch (err) {
    logger.error('GET /api/nodes/:nodeId failed', { nodeId, err });
    res.status(500).json({ error: 'failed_to_query_influx' });
  }
});

// Legacy redirects
app.get('/api/cows/:nodeId', (req, res) => res.redirect(`/api/nodes/${req.params.nodeId}`));
app.get('/nodejs/api/cows/:nodeId', (req, res) => res.redirect(`/api/nodes/${req.params.nodeId}`));

// Alias for Flutter web compatibility
app.get('/nodejs/api/nodes/:nodeId', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  try {
    const node0 = await getNodeById(nodeId);
    const nodes = await applyFriendlyNames(node0 ? [node0] : []);
    const node = nodes[0] || null;

    if (!node) {
      return res.status(404).json({ error: 'node_not_found' });
    }
    res.json(node);
  } catch (err) {
    logger.error('GET /nodejs/api/nodes/:nodeId failed', { nodeId, err });
    res.status(500).json({ error: 'failed_to_query_influx' });
  }
});

app.get('/api/nodes/:nodeId/history', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const hours = Number(req.query.hours || '24');
  const everyMinutes = Number(req.query.everyMinutes || '1');

  try {
    const points = await getNodeHistory({ nodeId, hours, everyMinutes });
    res.json(points);
  } catch (err) {
    logger.error('GET /api/nodes/:nodeId/history failed', { nodeId, err });
    res.status(500).json({ error: 'failed_to_query_influx' });
  }
});

// Legacy redirects
app.get('/api/cows/:nodeId/history', (req, res) => res.redirect(`/api/nodes/${req.params.nodeId}/history`));
app.get('/nodejs/api/cows/:nodeId/history', (req, res) => res.redirect(`/api/nodes/${req.params.nodeId}/history`));

// Alias for Flutter web compatibility
app.get('/nodejs/api/nodes/:nodeId/history', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const hours = Number(req.query.hours || '24');
  const everyMinutes = Number(req.query.everyMinutes || '1');

  try {
    const points = await getNodeHistory({ nodeId, hours, everyMinutes });
    res.json(points);
  } catch (err) {
    logger.error('GET /nodejs/api/nodes/:nodeId/history failed', { nodeId, err });
    res.status(500).json({ error: 'failed_to_query_influx' });
  }
});

app.get('/api/nodes/:nodeId/fence-history', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const hours = Number(req.query.hours || '24');
  const everyMinutes = Number(req.query.everyMinutes || '5');
  try {
    const points = await getFenceHistory({ nodeId, hours, everyMinutes });
    res.json(points);
  } catch (err) {
    logger.error('GET /api/nodes/:nodeId/fence-history failed', { nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_query_influx' });
  }
});

app.get('/nodejs/api/nodes/:nodeId/fence-history', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const hours = Number(req.query.hours || '24');
  const everyMinutes = Number(req.query.everyMinutes || '5');
  try {
    const points = await getFenceHistory({ nodeId, hours, everyMinutes });
    res.json(points);
  } catch (err) {
    logger.error('GET /nodejs/api/nodes/:nodeId/fence-history failed', { nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_query_influx' });
  }
});

app.get('/api/behavior/:nodeId', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const hours = req.query.hours ? Number(req.query.hours) : 24;
  try {
    const data = await getBehaviorData({ nodeId, hours });
    res.json({ nodeId: Number(nodeId), hours, data });
  } catch (err) {
    logger.error('GET /api/behavior/:nodeId failed', { nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_query_behavior_data' });
  }
});

app.get('/api/behavior/:nodeId/summary', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const date = req.query.date ? String(req.query.date) : null;
  try {
    const summary = await getBehaviorSummary({ nodeId, date });
    res.json({ nodeId: Number(nodeId), summary });
  } catch (err) {
    logger.error('GET /api/behavior/:nodeId/summary failed', { nodeId, date, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_query_behavior_summary' });
  }
});

app.get('/nodejs/api/behavior/:nodeId/summary', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const date = req.query.date ? String(req.query.date) : null;
  try {
    const summary = await getBehaviorSummary({ nodeId, date });
    res.json({ nodeId: Number(nodeId), summary });
  } catch (err) {
    logger.error('GET /nodejs/api/behavior/:nodeId/summary failed', { nodeId, date, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_query_behavior_summary' });
  }
});

app.get('/nodejs/api/behavior/:nodeId', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const hours = req.query.hours ? Number(req.query.hours) : 24;
  try {
    const data = await getBehaviorData({ nodeId, hours });
    res.json({ nodeId: Number(nodeId), hours, data });
  } catch (err) {
    logger.error('GET /nodejs/api/behavior/:nodeId failed', { nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_query_behavior_data' });
  }
});

// --- Unified alerts endpoint ---
// GET /nodejs/api/alerts — returns combined node_events + geofence_events (exit only).
// Resolved alerts excluded by default; pass ?includeResolved=true to include them.
app.get('/nodejs/api/alerts', requireAuth, async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 100, 500);
    const includeResolved = req.query.includeResolved === 'true';
    const severityFilter = req.query.severity ? String(req.query.severity) : null;

    const [nodeEventsRaw, geofenceEventsRaw] = await Promise.all([
      db.listNodeEvents({ limit }),
      db.listGeofenceEvents({ limit }),
    ]);

    const alerts = [];

    // Node events → alertKey = 'node_event:{id}'
    for (const e of nodeEventsRaw) {
      // Skip legacy dual-write geofence_breach rows (now only in geofence_events)
      if (e.type === 'geofence_breach') continue;
      if (!includeResolved && e.resolved) continue;
      if (severityFilter && e.severity !== severityFilter) continue;
      alerts.push({
        alertKey:   `node_event:${e.id}`,
        alertType:  e.type,
        severity:   e.severity,
        title:      _titleForEventType(e.type),
        message:    e.message,
        timestamp:  e.eventTime,
        nodeId:     e.nodeId,
        nodeName:   e.nodeName,
        lat:        e.lat,
        lon:        e.lon,
        resolved:   e.resolved || false,
        resolvedAt: e.resolvedAt || null,
      });
    }

    // Geofence exit events → alertKey = 'geofence_event:{id}'
    for (const e of geofenceEventsRaw) {
      if (e.type !== 'exit') continue;
      if (!includeResolved && e.resolved) continue;
      if (severityFilter && severityFilter !== 'critical') continue;
      alerts.push({
        alertKey:     `geofence_event:${e.id}`,
        alertType:    'geofence_breach',
        severity:     'critical',
        title:        'Geofence Breach',
        message:      `${e.nodeName || 'Node ' + e.nodeId} exited ${e.geofenceName || 'geofence ' + e.geofenceId}`,
        timestamp:    e.eventTime,
        nodeId:       e.nodeId,
        nodeName:     e.nodeName,
        geofenceId:   e.geofenceId,
        geofenceName: e.geofenceName,
        lat:          e.lat,
        lon:          e.lon,
        resolved:     e.resolved || false,
        resolvedAt:   e.resolvedAt || null,
      });
    }

    // Sort newest first
    alerts.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    res.json(alerts.slice(0, limit));
  } catch (err) {
    logger.error('GET /nodejs/api/alerts failed', { err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_list_alerts' });
  }
});

app.post('/nodejs/api/alerts/resolve', requireAuth, async (req, res) => {
  const { alertKey } = req.body || {};
  if (!alertKey || typeof alertKey !== 'string') {
    return res.status(400).json({ error: 'alertKey_required' });
  }
  try {
    await db.resolveAlert(alertKey);
    res.json({ ok: true });
  } catch (err) {
    logger.error('POST /nodejs/api/alerts/resolve failed', { alertKey, err: serializeError(err) });
    res.status(500).json({ error: 'failed_to_resolve_alert' });
  }
});

function _titleForEventType(type) {
  switch (type) {
    case 'voltage_low':         return 'Fence Voltage Fault';
    case 'battery_low':         return 'Low Battery';
    case 'node_offline':        return 'Node Offline';
    case 'geofence_breach':     return 'Geofence Breach';
    case 'health_deteriorated': return 'Health Status Alert';
    case 'reduced_rumination':  return 'Reduced Rumination';
    case 'abnormal_activity':   return 'Abnormal Activity';
    default:                    return 'Alert';
  }
}

// Daily cleanup of resolved events older than 90 days
setInterval(async () => {
  try {
    const deleted = await db.cleanupOldResolvedEvents(90);
    if (deleted > 0) logger.info('Cleaned up old resolved events', { deleted });
  } catch (err) {
    logger.error('Resolved events cleanup failed', { err: serializeError(err) });
  }
}, 24 * 60 * 60 * 1000);

app.get('/api/geofences', requireAuth, async (req, res) => {
  try {
    const fences = await db.listGeofences();
    const normalized = fences.map((f) => {
      const gj = safeJsonParse(f.geojson);
      return {
        id: f.id,
        name: f.name,
        geojson: gj || f.geojson,
        nodeIds: f.nodeIds,
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
      };
    });
    res.json(normalized);
  } catch (err) {
    logger.error('GET /api/geofences failed', { err });
    res.status(500).json({ error: 'failed_to_list_geofences' });
  }
});

// Alias for Flutter web compatibility
app.get('/nodejs/api/geofences', requireAuth, async (req, res) => {
  try {
    const fences = await db.listGeofences();
    const normalized = fences.map((f) => {
      const gj = safeJsonParse(f.geojson);
      return {
        id: f.id,
        name: f.name,
        geojson: gj || f.geojson,
        nodeIds: f.nodeIds,
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
      };
    });
    res.json(normalized);
  } catch (err) {
    logger.error('GET /nodejs/api/geofences failed', { err });
    res.status(500).json({ error: 'failed_to_list_geofences' });
  }
});

app.get('/api/geofence-events', requireAuth, async (req, res) => {
  try {
    const since = req.query.since ? String(req.query.since) : null;
    const limit = req.query.limit ? Number(req.query.limit) : 100;
    const nodeId = req.query.node_id ? Number(req.query.node_id) : null;
    const events = await db.listGeofenceEvents({ since, limit, nodeId });
    res.json(events);
  } catch (err) {
    logger.error('GET /api/geofence-events failed', { err });
    res.status(500).json({ error: 'failed_to_list_events' });
  }
});

// Alias for Flutter web compatibility
app.get('/nodejs/api/geofence-events', requireAuth, async (req, res) => {
  try {
    const since = req.query.since ? String(req.query.since) : null;
    const limit = req.query.limit ? Number(req.query.limit) : 100;
    const nodeId = req.query.node_id ? Number(req.query.node_id) : null;
    const events = await db.listGeofenceEvents({ since, limit, nodeId });
    res.json(events);
  } catch (err) {
    logger.error('GET /nodejs/api/geofence-events failed', { err });
    res.status(500).json({ error: 'failed_to_list_events' });
  }
});

app.get('/admin/nodes', requireAuth, async (req, res) => {
  try {
    const nodes = await db.listNodes();
    res.json(nodes);
  } catch (err) {
    logger.error('GET /admin/nodes failed', { err });
    res.status(500).json({ error: 'failed_to_list_nodes' });
  }
});

app.put('/admin/nodes/:nodeId', requireAuth, async (req, res) => {
  const { nodeId } = req.params;
  const { friendlyName, nodeType, staticLat, staticLon, breed, age, healthStatus, comments, photoUrl } = req.body || {};

  // Validate at least one field is provided
  if (!friendlyName && !nodeType && staticLat === undefined && staticLon === undefined && !breed && !age && !healthStatus && !comments && photoUrl === undefined) {
    return res.status(400).json({ error: 'at_least_one_field_required' });
  }

  try {
    // Read previous health status before update to detect deterioration
    const prevInfoMap = await db.getNodeInfoMap([Number(nodeId)]);
    const prevHealth = prevInfoMap[String(nodeId)]?.healthStatus || null;

    await db.upsertNodeInfo(nodeId, {
      friendlyName: friendlyName ? String(friendlyName).trim() || null : null,
      nodeType: nodeType ? String(nodeType).trim() || null : null,
      staticLat: staticLat !== undefined && staticLat !== null ? Number(staticLat) : null,
      staticLon: staticLon !== undefined && staticLon !== null ? Number(staticLon) : null,
      breed: breed ? String(breed).trim() || null : null,
      age: age ? Number(age) || null : null,
      healthStatus: healthStatus ? String(healthStatus).trim() || null : null,
      comments: comments ? String(comments).trim() || null : null,
      photoUrl: photoUrl !== undefined ? (photoUrl ? String(photoUrl).trim() : null) : null,
    });

    // Fire a node event if health status deteriorated
    const DETERIORATED = ['sick', 'injured', 'critical', 'poor', 'ill'];
    const newHealth = healthStatus ? String(healthStatus).trim().toLowerCase() : null;
    if (newHealth && DETERIORATED.includes(newHealth) && newHealth !== (prevHealth || '').toLowerCase()) {
      try {
        await db.insertNodeEvent({
          nodeId: Number(nodeId),
          type: 'health_deteriorated',
          severity: newHealth === 'critical' ? 'critical' : 'warning',
          message: `Health status changed to "${healthStatus}"`,
          eventTime: new Date().toISOString(),
          lat: null,
          lon: null,
        });
        broadcast({
          type: 'node_alert',
          alertType: 'health_deteriorated',
          nodeId: Number(nodeId),
          healthStatus: healthStatus,
          message: `Node ${nodeId} health status: ${healthStatus}`,
        });
      } catch (evErr) {
        logger.error('PUT /admin/nodes/:nodeId: insertNodeEvent (health) failed', { nodeId, err: evErr });
      }
    }

    res.json({ ok: true });
  } catch (err) {
    logger.error('PUT /admin/nodes/:nodeId failed', { nodeId, err });
    res.status(500).json({ error: 'failed_to_update_node' });
  }
});

// Photo upload endpoint — accepts multipart form with 'photo' field
app.post('/admin/nodes/:nodeId/photo', requireAuth, photoUpload.single('photo'), async (req, res) => {
  const { nodeId } = req.params;
  if (!req.file) {
    return res.status(400).json({ error: 'no_file_uploaded' });
  }
  try {
    // Build an absolute URL using /api/uploads path for Cloudflare tunnel compatibility
    const relPath = `/api/uploads/photos/${req.file.filename}`;
    // Force HTTPS since Cloudflare handles SSL termination
    const photoUrl = `https://${req.get('host')}${relPath}`;
    logger.info('Photo uploaded', { nodeId, filename: req.file.filename, photoUrl });
    await db.updateNodePhotoUrl(nodeId, photoUrl);
    logger.info('Photo URL saved to database', { nodeId, photoUrl });
    res.json({ ok: true, photoUrl });
  } catch (err) {
    logger.error('POST /admin/nodes/:nodeId/photo failed', { nodeId, err: err.message || err });
    res.status(500).json({ error: 'failed_to_upload_photo' });
  }
});

// Node provisioning endpoint - assigns next available node_id
app.post('/api/provision/node', requireAuth, async (req, res) => {
  try {
    const nextNodeId = await db.getNextAvailableNodeId();

    // Create the node entry with default values
    const now = new Date().toISOString();
    await db.upsertNodeInfo(nextNodeId, {
      friendlyName: `Node ${nextNodeId}`,
      breed: null,
      age: null,
      healthStatus: null,
      comments: 'Auto-provisioned via API'
    });

    logger.info('Node provisioned', { nodeId: nextNodeId });

    res.json({
      nodeId: nextNodeId,
      friendlyName: `Node ${nextNodeId}`,
      status: 'provisioned'
    });
  } catch (err) {
    if (err.message === 'no_available_node_ids') {
      return res.status(409).json({ error: 'no_available_node_ids', message: 'All node IDs (1-255) are in use' });
    }
    logger.error('POST /api/provision/node failed', { err });
    res.status(500).json({ error: 'provisioning_failed' });
  }
});

app.get('/admin/geofences', requireAuth, async (req, res) => {
  try {
    const fences = await db.listGeofences();
    const normalized = fences.map((f) => {
      const gj = safeJsonParse(f.geojson);
      return {
        id: f.id,
        name: f.name,
        geojson: gj || f.geojson,
        nodeIds: f.nodeIds,
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
      };
    });
    res.json(normalized);
  } catch (err) {
    logger.error('GET /admin/geofences failed', { err });
    res.status(500).json({ error: 'failed_to_list_geofences' });
  }
});

app.post('/admin/geofences', requireAuth, async (req, res) => {
  const name = String(req.body?.name || '').trim();
  const geojson = req.body?.geojson;
  if (!name) {
    return res.status(400).json({ error: 'name_required' });
  }
  if (geojson === undefined || geojson === null) {
    return res.status(400).json({ error: 'geojson_required' });
  }

  try {
    const geojsonStr = typeof geojson === 'string' ? geojson : JSON.stringify(geojson);
    parseGeoJsonPolygon(geojsonStr);
    const id = await db.createGeofence(name, geojsonStr);
    if (mqttGeofenceSync) {
      const nodeIds = await db.listNodeIdsForGeofence(id);
      if (nodeIds.length) {
        await mqttGeofenceSync.publishGeofencesForNodeIds(nodeIds, 'geofence_create', { bumpVersion: true });
      }
    }
    res.json({ ok: true, id });
  } catch (err) {
    logger.error('POST /admin/geofences failed', { err });
    res.status(400).json({ error: 'invalid_geojson' });
  }
});

app.put('/admin/geofences/:id', requireAuth, async (req, res) => {
  const { id } = req.params;
  const patch = {};

  if (req.body?.name !== undefined) {
    patch.name = String(req.body.name).trim();
    if (!patch.name) {
      return res.status(400).json({ error: 'name_required' });
    }
  }

  if (req.body?.geojson !== undefined) {
    const geojson = req.body.geojson;
    const geojsonStr = typeof geojson === 'string' ? geojson : JSON.stringify(geojson);
    try {
      parseGeoJsonPolygon(geojsonStr);
    } catch (_) {
      return res.status(400).json({ error: 'invalid_geojson' });
    }
    patch.geojson = geojsonStr;
  }

  try {
    const ok = await db.updateGeofence(id, patch);
    if (!ok) return res.status(404).json({ error: 'not_found' });
    if (mqttGeofenceSync && patch.geojson !== undefined) {
      const nodeIds = await db.listNodeIdsForGeofence(id);
      await mqttGeofenceSync.publishGeofencesForNodeIds(nodeIds, 'geofence_update', { bumpVersion: true });
    }
    res.json({ ok: true });
  } catch (err) {
    logger.error('PUT /admin/geofences/:id failed', { id, err });
    res.status(500).json({ error: 'failed_to_update_geofence' });
  }
});

app.delete('/admin/geofences/:id', requireAuth, async (req, res) => {
  const { id } = req.params;
  try {
    let nodeIds = [];
    if (mqttGeofenceSync) {
      nodeIds = await db.listNodeIdsForGeofence(id);
    }
    await db.deleteGeofence(id);
    if (mqttGeofenceSync && nodeIds.length) {
      // Publish empty vertices with bumped version so trackers can clear their cached geofence.
      await mqttGeofenceSync.publishGeofencesForNodeIds(nodeIds, 'geofence_delete', { bumpVersion: true });
    }
    res.json({ ok: true });
  } catch (err) {
    logger.error('DELETE /admin/geofences/:id failed', { id, err });
    res.status(500).json({ error: 'failed_to_delete_geofence' });
  }
});

app.put('/admin/geofences/:id/nodes', requireAuth, async (req, res) => {
  const { id } = req.params;
  const nodeIds = Array.isArray(req.body?.nodeIds) ? req.body.nodeIds : null;
  if (!nodeIds) {
    return res.status(400).json({ error: 'node_ids_required' });
  }
  try {
    let prevNodeIds = [];
    if (mqttGeofenceSync) {
      prevNodeIds = await db.listNodeIdsForGeofence(id);
    }
    await db.setGeofenceNodes(id, nodeIds);
    if (mqttGeofenceSync) {
      const nextNodeIds = Array.from(new Set(nodeIds.map((n) => Number(n)).filter((n) => Number.isFinite(n))));
      const prevSet = new Set(prevNodeIds);
      const nextSet = new Set(nextNodeIds);

      const added = nextNodeIds.filter((n) => !prevSet.has(n));
      const removed = prevNodeIds.filter((n) => !nextSet.has(n));
      const unchanged = nextNodeIds.filter((n) => prevSet.has(n));

      if (added.length) {
        await mqttGeofenceSync.publishGeofencesForNodeIds(added, 'geofence_assign', { bumpVersion: true });
      }
      if (removed.length) {
        await mqttGeofenceSync.publishGeofencesForNodeIds(removed, 'geofence_unassign', { bumpVersion: true });
      }
      if (unchanged.length) {
        // Don't bump version for unchanged nodes - geofence data hasn't changed.
        // This avoids double-publish when updateGeofence() already bumped the version.
        await mqttGeofenceSync.publishGeofencesForNodeIds(unchanged, 'geofence_assign_refresh', { bumpVersion: false });
      }
    }
    res.json({ ok: true });
  } catch (err) {
    logger.error('PUT /admin/geofences/:id/nodes failed', { id, err });
    res.status(500).json({ error: 'failed_to_update_geofence_nodes' });
  }
});

function requireAuth(req, res, next) {
  const adminUser = process.env.ADMIN_USERNAME;
  const adminPass = process.env.ADMIN_PASSWORD;
  if (!adminUser || !adminPass) {
    return res.status(403).json({ error: 'admin_disabled' });
  }
  if (!req.session?.user?.username) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  next();
}

function safeJsonParse(s) {
  try {
    return JSON.parse(s);
  } catch (_) {
    return null;
  }
}

async function applyFriendlyNames(nodes) {
  const nodeIds = nodes.map((n) => n.nodeId);
  const map = await db.getNodeInfoMap(nodeIds);
  return nodes.map((n) => {
    const info = map[String(n.nodeId)];
    if (info) {
      // If it's a fence or manually-placed node, use static coordinates from DB
      const hasStaticLoc = info.staticLat !== null && info.staticLon !== null;
      const useStatic = info.nodeType === 'fence' || hasStaticLoc;

      return {
        ...n,
        name: info.friendlyName || n.name,
        deviceId: info.deviceId ?? null,
        nodeType: info.nodeType || 'cow',
        latitude: useStatic ? info.staticLat : n.latitude,
        longitude: useStatic ? info.staticLon : n.longitude,
        breed: info.breed,
        age: info.age,
        healthStatus: info.healthStatus,
        comments: info.comments,
        photoUrl: info.photoUrl || null,
        isNew: info.nodeType === 'fence' && (info.staticLat === null || info.staticLat === undefined), // Tag for UI placement notification
      };
    }
    return {
      ...n,
      nodeType: 'cow', // Default
      isNew: true, // Not in DB yet
    };
  });
}

async function runVoltageChecksForNodes(nodes, broadcast) {
  const fenceNodes = nodes.filter(n => n.nodeType === 'fence' && n.voltage !== null);
  if (!fenceNodes.length) return;

  const VOLTAGE_THRESHOLD = 5000; // 5kV threshold for "Power Cut"

  for (const node of fenceNodes) {
    if (node.voltage < VOLTAGE_THRESHOLD) {
      // Check if we already have a recent event for this to avoid spam
      const recentEvents = await db.listNodeEvents({ nodeId: node.nodeId, limit: 1 });
      const lastEvent = recentEvents[0];
      const tooSoon = lastEvent &&
        lastEvent.type === 'voltage_low' &&
        (Date.now() - new Date(lastEvent.eventTime).getTime() < 3600000); // 1 hour cooldown

      if (!tooSoon) {
        logger.warn('Fence voltage low detected', { nodeId: node.nodeId, voltage: node.voltage });

        await db.insertNodeEvent({
          nodeId: node.nodeId,
          type: 'voltage_low',
          severity: 'error',
          message: `Fence voltage critically low: ${node.voltage}V`,
          eventTime: new Date().toISOString(),
          lat: node.latitude,
          lon: node.longitude
        });

        broadcast({
          type: 'node_alert',
          alertType: 'voltage_low',
          nodeId: node.nodeId,
          nodeName: node.name,
          voltage: node.voltage,
          message: `Fence fault detected on ${node.name}!`
        });
      }
    }
  }
}

const _offlineCooldowns = new Map(); // nodeId -> lastAlertTime (ms)
const OFFLINE_THRESHOLD_MS = 2 * 60 * 60 * 1000; // 2 hours
const OFFLINE_ALERT_COOLDOWN_MS = 4 * 60 * 60 * 1000; // 4 hours between repeated alerts

async function runOfflineChecksForNodes(nodes, broadcast) {
  const now = Date.now();
  for (const node of nodes) {
    if (!node.lastUpdated) continue;
    const age = now - new Date(node.lastUpdated).getTime();
    if (age < OFFLINE_THRESHOLD_MS) continue;

    const lastAlert = _offlineCooldowns.get(node.nodeId) || 0;
    if (now - lastAlert < OFFLINE_ALERT_COOLDOWN_MS) continue;

    _offlineCooldowns.set(node.nodeId, now);
    logger.warn('Node offline detected', { nodeId: node.nodeId, lastUpdated: node.lastUpdated });

    try {
      await db.insertNodeEvent({
        nodeId: node.nodeId,
        type: 'node_offline',
        severity: 'critical',
        message: `Node ${node.name || node.nodeId} has not reported for ${Math.round(age / 3600000)}h`,
        eventTime: new Date().toISOString(),
        lat: node.latitude,
        lon: node.longitude,
      });
    } catch (evErr) {
      logger.error('runOfflineChecksForNodes: insertNodeEvent failed', { nodeId: node.nodeId, err: evErr });
    }

    if (typeof broadcast === 'function') {
      broadcast({
        type: 'node_alert',
        alertType: 'offline',
        nodeId: node.nodeId,
        nodeName: node.name,
        message: `Node ${node.name || node.nodeId} is offline`,
      });
    }
  }
}

async function runGeofenceChecksForNodes(nodes, broadcast) {
  if (!nodes.length) return;

  const nodeIds = nodes.map((n) => n.nodeId);
  const assignmentsByNodeId = await db.getAssignedGeofencesForNodeIds(nodeIds);
  await runGeofenceExitCheck({
    nodes: nodes, // Fix: function expects 'nodes', not 'cows'
    assignmentsByNodeId,
    db,
    broadcast,
    logger,
  });
}

// --- Behavior & health alert checks (runs every ~15 min) ---
const BEHAVIOR_ALERT_COOLDOWN_MS = 6 * 60 * 60 * 1000; // 6 hours per node
const MIN_TRACKING_HOURS = 12;
const MIN_TODAY_MINUTES = 240; // need >=4h of data today to extrapolate
const _behaviorAlertCooldowns = new Map();

async function runBehaviorHealthChecks(nodes, broadcast) {
  const trackerNodes = nodes.filter(n => !isNaN(n.latitude) && !isNaN(n.longitude));
  if (!trackerNodes.length) return;

  const now = Date.now();

  for (const node of trackerNodes) {
    const nodeId = node.nodeId;

    // Check cooldown first (cheap)
    const lastAlert = _behaviorAlertCooldowns.get(nodeId) || 0;
    if (now - lastAlert < BEHAVIOR_ALERT_COOLDOWN_MS) continue;

    try {
      // Check minimum tracking age
      const firstSeen = await getNodeTrackingAge(nodeId);
      if (!firstSeen) continue;
      const trackingHours = (now - firstSeen.getTime()) / (1000 * 60 * 60);
      if (trackingHours < MIN_TRACKING_HOURS) continue;

      // Get today's behavior summary
      const summary = await getBehaviorSummary({ nodeId });
      const totalMinutes = (summary.ruminating_minutes || 0) +
        (summary.grazing_minutes || 0) +
        (summary.resting_minutes || 0) +
        (summary.moving_minutes || 0) +
        (summary.feeding_minutes || 0);

      if (totalMinutes < MIN_TODAY_MINUTES) continue; // not enough data today

      // Extrapolate to daily rate (24h)
      const scale = (24 * 60) / totalMinutes;
      const ruminatingPerDay = (summary.ruminating_minutes || 0) * scale;
      const restingPerDay = (summary.resting_minutes || 0) * scale;
      const movingPerDay = (summary.moving_minutes || 0) * scale;
      const feedingGrazingPerDay = ((summary.feeding_minutes || 0) + (summary.grazing_minutes || 0)) * scale;

      const alerts = [];

      // Rumination checks
      if (ruminatingPerDay < 240) {
        alerts.push({ type: 'reduced_rumination', severity: 'critical',
          message: `Node ${node.name || nodeId}: critically low rumination (~${Math.round(ruminatingPerDay / 60)}h/day, expected 6-10h)` });
      } else if (ruminatingPerDay < 360) {
        alerts.push({ type: 'reduced_rumination', severity: 'warning',
          message: `Node ${node.name || nodeId}: reduced rumination (~${Math.round(ruminatingPerDay / 60)}h/day, expected 6-10h)` });
      }

      // Resting checks
      if (restingPerDay > 960) {
        alerts.push({ type: 'abnormal_activity', severity: 'critical',
          message: `Node ${node.name || nodeId}: excessive resting (~${Math.round(restingPerDay / 60)}h/day)` });
      } else if (restingPerDay > 720) {
        alerts.push({ type: 'abnormal_activity', severity: 'warning',
          message: `Node ${node.name || nodeId}: high resting (~${Math.round(restingPerDay / 60)}h/day)` });
      }

      // Movement check
      if (movingPerDay < 60) {
        alerts.push({ type: 'abnormal_activity', severity: 'warning',
          message: `Node ${node.name || nodeId}: very low movement (~${Math.round(movingPerDay)}min/day)` });
      }

      // Feeding + grazing check
      if (feedingGrazingPerDay < 240) {
        alerts.push({ type: 'abnormal_activity', severity: 'warning',
          message: `Node ${node.name || nodeId}: low feeding/grazing (~${Math.round(feedingGrazingPerDay / 60)}h/day)` });
      }

      if (alerts.length > 0) {
        _behaviorAlertCooldowns.set(nodeId, now);
        const ts = new Date().toISOString();

        for (const a of alerts) {
          try {
            await db.insertNodeEvent({
              nodeId,
              type: a.type,
              severity: a.severity,
              message: a.message,
              eventTime: ts,
              lat: node.latitude ?? null,
              lon: node.longitude ?? null,
            });
          } catch (evErr) {
            logger.error('runBehaviorHealthChecks: insertNodeEvent failed', { nodeId, type: a.type, err: evErr });
          }

          if (typeof broadcast === 'function') {
            try {
              broadcast({
                type: 'node_alert',
                alertType: a.type,
                severity: a.severity,
                nodeId,
                nodeName: node.name,
                message: a.message,
              });
            } catch (wsErr) {
              logger.error('runBehaviorHealthChecks: broadcast failed', { nodeId, err: wsErr });
            }
          }
        }

        logger.info('Behavior health alerts generated', { nodeId, count: alerts.length });
      }
    } catch (err) {
      logger.error('runBehaviorHealthChecks failed for node', { nodeId, err: serializeError(err) });
    }
  }
}

app.get('/admin/logs', requireAuth, (req, res) => {
  const lines = Math.min(Number(req.query.lines || '200'), 2000);
  try {
    const content = fs.existsSync(LOG_FILE) ? fs.readFileSync(LOG_FILE, 'utf8') : '';
    const allLines = content.split(/\r?\n/);
    const tail = allLines.slice(Math.max(0, allLines.length - lines));
    res.type('text/plain').send(tail.join('\n'));
  } catch (err) {
    logger.error('GET /admin/logs failed', { err });
    res.status(500).json({ error: 'failed_to_read_logs' });
  }
});

app.post('/admin/log-level', requireAuth, (req, res) => {
  const level = String(req.body?.level || '').toLowerCase();
  const allowed = new Set(['debug', 'info', 'error']);
  if (!allowed.has(level)) {
    return res.status(400).json({ error: 'invalid_level' });
  }
  setLogLevel(level);
  logger.info('Log level changed', { level });
  res.json({ ok: true, level });
});

// AI Development Analytics Endpoints
app.get('/api/dev/battery/:nodeId', requireAuth, async (req, res) => {
  if (!aiAnalytics) {
    return res.status(503).json({ error: 'ai_analytics_not_initialized' });
  }
  try {
    const timeRange = req.query.timeRange || '-24h';
    const result = await aiAnalytics.estimateBatteryLife(req.params.nodeId, timeRange);
    res.json(result);
  } catch (err) {
    logger.error('GET /api/dev/battery/:nodeId failed', { nodeId: req.params.nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'battery_analysis_failed', message: err.message });
  }
});

app.get('/api/dev/range/:nodeId?', requireAuth, async (req, res) => {
  if (!aiAnalytics) {
    return res.status(503).json({ error: 'ai_analytics_not_initialized' });
  }
  try {
    const timeRange = req.query.timeRange || '-24h';
    const result = await aiAnalytics.analyzeRange(req.params.nodeId || null, timeRange);
    res.json(result);
  } catch (err) {
    logger.error('GET /api/dev/range failed', { nodeId: req.params.nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'range_analysis_failed', message: err.message });
  }
});

app.get('/api/dev/health', requireAuth, async (req, res) => {
  if (!aiAnalytics) {
    return res.status(503).json({ error: 'ai_analytics_not_initialized' });
  }
  try {
    const timeRange = req.query.timeRange || '-1h';
    const result = await aiAnalytics.monitorSystemHealth(timeRange);
    res.json(result);
  } catch (err) {
    logger.error('GET /api/dev/health failed', { err: serializeError(err) });
    res.status(500).json({ error: 'health_monitoring_failed', message: err.message });
  }
});

app.get('/api/dev/report/:nodeId?', requireAuth, async (req, res) => {
  if (!aiAnalytics) {
    return res.status(503).json({ error: 'ai_analytics_not_initialized' });
  }
  try {
    const result = await aiAnalytics.generateDevReport(req.params.nodeId || null);
    res.json(result);
  } catch (err) {
    logger.error('GET /api/dev/report failed', { nodeId: req.params.nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'report_generation_failed', message: err.message });
  }
});

// Shared coverage query handler
// Queries two sources:
//   1. 'position' measurement  — every successful uplink (rssi = gateway-observed signal strength)
//   2. 'coverage_failures' measurement — dead-zone points reported by the tracker
async function handleCoverageQuery(req, res, routeName) {
  try {
    const { InfluxDB } = require('@influxdata/influxdb-client');
    const influxDB = new InfluxDB({
      url: process.env.INFLUXDB_URL || 'http://localhost:8086',
      token: process.env.INFLUXDB_TOKEN
    });
    const queryApi = influxDB.getQueryApi(process.env.INFLUXDB_ORG);
    const bucket = process.env.INFLUXDB_BUCKET || 'moopoint';

    const nodeId = req.params.nodeId;
    const timeRange = req.query.timeRange || '24h';

    // --- Query 1: position measurement (successful uplinks with gateway-measured RSSI) ---
    // 'rssi' = RSSI measured by the gateway on each received uplink (present in ALL packets).
    // Do NOT use 'ext_tracker_rssi' — that is the tracker's own RX RSSI and is rarely present.
    let positionQuery = `from(bucket: "${bucket}")
      |> range(start: -${timeRange})
      |> filter(fn: (r) => r["_measurement"] == "position")
      |> filter(fn: (r) => r["device_type"] == "tracker")
      |> filter(fn: (r) => r["_field"] == "lat" or r["_field"] == "lon" or r["_field"] == "rssi")
      |> pivot(rowKey:["_time", "node_id"], columnKey: ["_field"], valueColumn: "_value")
      |> filter(fn: (r) => exists r["lat"] and exists r["lon"] and r["lat"] != 0.0 and r["lon"] != 0.0)`;

    if (nodeId) {
      positionQuery += `\n  |> filter(fn: (r) => r["node_id"] == "${nodeId}")`;
    }

    // --- Query 2: coverage_failures measurement (dead-zone failure points from tracker) ---
    let failureQuery = `from(bucket: "${bucket}")
      |> range(start: -${timeRange})
      |> filter(fn: (r) => r["_measurement"] == "coverage_failures")
      |> filter(fn: (r) => r["_field"] == "lat" or r["_field"] == "lon" or r["_field"] == "rssi")
      |> pivot(rowKey:["_time", "node_id"], columnKey: ["_field"], valueColumn: "_value")
      |> filter(fn: (r) => exists r["lat"] and exists r["lon"] and r["lat"] != 0.0 and r["lon"] != 0.0)`;

    if (nodeId) {
      failureQuery += `\n  |> filter(fn: (r) => r["node_id"] == "${nodeId}")`;
    }

    const coveragePoints = [];
    let totalRssi = 0;
    let rssiCount = 0;
    let goodSignal = 0;
    let mediumSignal = 0;
    let poorSignal = 0;

    function processRow(o, source) {
      const rssi = o.rssi != null ? Number(o.rssi) : null;
      const point = {
        lat: o.lat,
        lon: o.lon,
        timestamp: new Date(o._time).getTime(),
        rssi,
        nodeId: o.node_id,
        source  // 'position' or 'failure'
      };
      coveragePoints.push(point);
      if (rssi != null) {
        totalRssi += rssi;
        rssiCount++;
        if (rssi >= -90) goodSignal++;
        else if (rssi >= -105) mediumSignal++;
        else poorSignal++;
      }
    }

    // Run both queries; tolerate failure of the failures query (may not exist yet)
    await queryApi.collectRows(positionQuery)
      .then((rows) => rows.forEach((o) => processRow(o, 'position')))
      .catch((err) => logger.error(`${routeName}: position query failed`, { err: serializeError(err) }));

    await queryApi.collectRows(failureQuery)
      .then((rows) => rows.forEach((o) => processRow(o, 'failure')))
      .catch((err) => logger.warn(`${routeName}: coverage_failures query failed (may be empty)`, { msg: err.message }));

    res.json({
      nodeId: nodeId || 'all',
      timeRange,
      points: coveragePoints,
      summary: {
        totalPoints: coveragePoints.length,
        pointsWithRssi: rssiCount,
        avgRssi: rssiCount > 0 ? parseFloat((totalRssi / rssiCount).toFixed(1)) : null,
        goodSignal,
        mediumSignal,
        poorSignal
      }
    });
  } catch (err) {
    logger.error(`${routeName} failed`, { nodeId: req.params.nodeId, err: serializeError(err) });
    res.status(500).json({ error: 'coverage_query_failed', message: err.message });
  }
}

// Coverage mapping endpoint - shows all positions colored by RSSI
app.get('/api/coverage/:nodeId?', requireAuth, (req, res) => handleCoverageQuery(req, res, 'GET /api/coverage'));

// Alias for Flutter web compatibility
app.get('/nodejs/api/coverage/:nodeId?', requireAuth, (req, res) => handleCoverageQuery(req, res, 'GET /nodejs/api/coverage'));

// Firmware management endpoints
app.post('/admin/firmware/upload', requireAuth, firmwareUpload.single('firmware'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'no_file_uploaded' });
    }

    const version = req.body.version || 'unknown';
    const notes = req.body.notes || '';
    const hexPath = req.file.path;
    const hexFilename = req.file.filename;
    const zipFilename = hexFilename.replace('.hex', '.zip');
    const zipPath = path.join(firmwareManager.FIRMWARE_DIR, zipFilename);

    // Validate HEX file
    const validation = firmwareManager.validateHexFile(hexPath);
    if (!validation.valid) {
      fs.unlinkSync(hexPath);
      return res.status(400).json({ error: 'invalid_hex_file', message: validation.error });
    }

    // Generate DFU package
    const dfuResult = firmwareManager.generateDfuPackage(hexPath, zipPath);
    if (!dfuResult.success) {
      fs.unlinkSync(hexPath);
      return res.status(500).json({ error: 'dfu_generation_failed', message: dfuResult.error });
    }

    // Calculate checksum
    const checksum = firmwareManager.calculateChecksum(hexPath);
    const fileSize = fs.statSync(zipPath).size;

    // Save to database
    const firmwareId = await db.createFirmwareVersion(version, hexFilename, zipFilename, fileSize, checksum, notes);

    // Cleanup old firmware (keep last 5)
    const deletedCount = await db.cleanupOldFirmware(5);
    if (deletedCount > 0) {
      logger.info('Cleaned up old firmware versions', { deletedCount });
    }

    logger.info('Firmware uploaded successfully', { firmwareId, version, hexFilename, zipFilename });
    res.json({ ok: true, firmwareId, version, fileSize, checksum });
  } catch (err) {
    logger.error('Firmware upload failed', { err: serializeError(err) });
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    res.status(500).json({ error: 'upload_failed', message: err.message });
  }
});

app.get('/admin/firmware/list', requireAuth, async (req, res) => {
  try {
    const versions = await db.listFirmwareVersions();
    res.json(versions);
  } catch (err) {
    logger.error('Failed to list firmware versions', { err: serializeError(err) });
    res.status(500).json({ error: 'list_failed' });
  }
});

app.get('/admin/firmware/download/:id', requireAuth, async (req, res) => {
  try {
    const firmware = await db.getFirmwareVersion(req.params.id);
    if (!firmware) {
      return res.status(404).json({ error: 'firmware_not_found' });
    }

    const zipPath = path.join(firmwareManager.FIRMWARE_DIR, firmware.filename_zip);
    if (!fs.existsSync(zipPath)) {
      return res.status(404).json({ error: 'file_not_found' });
    }

    res.download(zipPath, `firmware_${firmware.version}.zip`);
  } catch (err) {
    logger.error('Firmware download failed', { err: serializeError(err) });
    res.status(500).json({ error: 'download_failed' });
  }
});

app.post('/admin/firmware/set_active/:id', requireAuth, async (req, res) => {
  try {
    const firmware = await db.getFirmwareVersion(req.params.id);
    if (!firmware) {
      return res.status(404).json({ error: 'firmware_not_found' });
    }

    await db.setActiveFirmware(req.params.id);
    logger.info('Set active firmware', { firmwareId: req.params.id, version: firmware.version });
    res.json({ ok: true });
  } catch (err) {
    logger.error('Failed to set active firmware', { err: serializeError(err) });
    res.status(500).json({ error: 'set_active_failed' });
  }
});

app.delete('/admin/firmware/:id', requireAuth, async (req, res) => {
  try {
    const firmware = await db.getFirmwareVersion(req.params.id);
    if (!firmware) {
      return res.status(404).json({ error: 'firmware_not_found' });
    }

    if (firmware.is_active) {
      return res.status(400).json({ error: 'cannot_delete_active_firmware' });
    }

    // Delete files
    firmwareManager.deleteFirmwareFiles(firmware.filename_hex, firmware.filename_zip);

    // Delete from database
    await db.deleteFirmwareVersion(req.params.id);

    logger.info('Firmware deleted', { firmwareId: req.params.id, version: firmware.version });
    res.json({ ok: true });
  } catch (err) {
    logger.error('Failed to delete firmware', { err: serializeError(err) });
    res.status(500).json({ error: 'delete_failed' });
  }
});

// Config push endpoints
app.post('/admin/config/push', requireAuth, async (req, res) => {
  try {
    const { nodeIds, config, gatewayIds } = req.body;

    if (!nodeIds || !Array.isArray(nodeIds) || nodeIds.length === 0) {
      return res.status(400).json({ error: 'node_ids_required' });
    }

    if (!config || typeof config !== 'object') {
      return res.status(400).json({ error: 'config_required' });
    }

    if (!gatewayIds || !Array.isArray(gatewayIds) || gatewayIds.length === 0) {
      return res.status(400).json({ error: 'gateway_ids_required' });
    }

    const { v4: uuidv4 } = require('uuid');
    const requestId = uuidv4();

    // Save config push request
    await db.createConfigPushRequest(requestId, nodeIds, JSON.stringify(config));

    // Initialize status for all nodes
    for (const nodeId of nodeIds) {
      await db.updateConfigPushStatus(requestId, nodeId, 'pending', null);

      // Increment config version for this node
      const newVersion = await db.incrementConfigVersion(nodeId);

      // Save config to tracker_configs table
      await db.saveTrackerConfig(nodeId, JSON.stringify(config), newVersion);
    }

    // Publish config updates to all specified gateways for each node
    const publishPromises = [];
    for (const nodeId of nodeIds) {
      const trackerConfig = await db.getTrackerConfig(nodeId);
      const configVersion = trackerConfig ? trackerConfig.config_version : 1;

      for (const gatewayId of gatewayIds) {
        publishPromises.push(
          mqttConfigPush.publishConfigUpdate(gatewayId, nodeId, config, configVersion)
            .then(() => {
              db.updateConfigPushStatus(requestId, nodeId, 'sent', null);
            })
            .catch((err) => {
              db.updateConfigPushStatus(requestId, nodeId, 'failed', err.message);
            })
        );
      }
    }

    await Promise.allSettled(publishPromises);

    logger.info('Config push initiated', { requestId, nodeIds, gatewayIds });
    res.json({ ok: true, requestId, nodeIds, gatewayIds });
  } catch (err) {
    logger.error('Config push failed', { err: serializeError(err) });
    res.status(500).json({ error: 'config_push_failed', message: err.message });
  }
});

app.get('/admin/config/push/:requestId/status', requireAuth, async (req, res) => {
  try {
    const { requestId } = req.params;
    const status = await db.getConfigPushStatus(requestId);
    res.json(status);
  } catch (err) {
    logger.error('Failed to get config push status', { err: serializeError(err) });
    res.status(500).json({ error: 'status_query_failed' });
  }
});

app.get('/admin/config/:nodeId', requireAuth, async (req, res) => {
  try {
    const { nodeId } = req.params;
    const config = await db.getTrackerConfig(nodeId);
    if (!config) {
      return res.status(404).json({ error: 'config_not_found' });
    }
    res.json(config);
  } catch (err) {
    logger.error('Failed to get tracker config', { err: serializeError(err) });
    res.status(500).json({ error: 'config_query_failed' });
  }
});

app.get('/api/admin/config/push/:requestId/status', requireAuth, async (req, res) => {
  try {
    const { requestId } = req.params;
    const status = await db.getConfigPushStatus(requestId);
    res.json(status);
  } catch (err) {
    logger.error('Failed to get config push status', { err: serializeError(err) });
    res.status(500).json({ error: 'status_query_failed' });
  }
});

app.get('/api/admin/config/:nodeId', requireAuth, async (req, res) => {
  try {
    const { nodeId } = req.params;
    const config = await db.getTrackerConfig(nodeId);
    if (!config) {
      return res.status(404).json({ error: 'config_not_found' });
    }
    res.json(config);
  } catch (err) {
    logger.error('Failed to get tracker config', { err: serializeError(err) });
    res.status(500).json({ error: 'config_query_failed' });
  }
});

// Debug endpoint to check AI analytics status
app.get('/api/debug/ai-analytics', requireAuth, (req, res) => {
  res.json({
    initialized: aiAnalytics !== null,
    influxEnvVars: {
      url: !!process.env.INFLUXDB_URL || !!process.env.INFLUX_URL,
      token: !!process.env.INFLUXDB_TOKEN || !!process.env.INFLUX_TOKEN,
      org: !!process.env.INFLUXDB_ORG || !!process.env.INFLUX_ORG,
      bucket: !!process.env.INFLUXDB_BUCKET || !!process.env.INFLUX_BUCKET
    }
  });
});

// Debug endpoint to check InfluxDB configuration
app.get('/debug/influx-config', requireAuth, (req, res) => {
  try {
    const cfg = require('./influx').getInfluxConfig();
    res.json({
      bucket: cfg.bucket,
      measurement: cfg.measurement,
      deviceType: cfg.deviceType,
      deviceTypeTag: cfg.deviceTypeTag,
      deviceIdTag: cfg.deviceIdTag,
      timeRangeHours: cfg.timeRangeHours,
      url: cfg.url
    });
  } catch (err) {
    res.status(500).json({ error: 'failed_to_get_config', message: err.message });
  }
});

const port = Number(process.env.PORT || '8080');

const server = http.createServer(app);
const { broadcast } = createWsServer({ server, logger, sessionParser });

let mqttGeofenceSync = null;
let mqttDeviceMapSync = null;
let mqttTrackerSubscriber = null;
let mqttFenceSubscriber = null;
let aiAnalytics = null;

// Initialize shared MQTT client and set up BLE locate topic
function initMqttClient() {
  const url = process.env.MQTT_URL || 'mqtt://127.0.0.1:1883';
  const username = process.env.MQTT_USERNAME || undefined;
  const password = process.env.MQTT_PASSWORD || undefined;
  const gatewayId = process.env.GATEWAY_ID || '1';
  const topic = `moopoint/cmd/gateway/${gatewayId}/ble_locate`;

  logger.info('Initializing shared MQTT client', {
    url,
    gatewayId,
    topic,
    hasAuth: !!(username && password)
  });

  const client = require('mqtt').connect(url, { username, password });

  client.on('connect', () => {
    logger.info('Shared MQTT client connected', {
      url,
      topic,
      clientId: client.options.clientId,
      connected: client.connected
    });
    mqttClient = client;
    mqttLocateTopic = topic;

    // Initialize config push module with MQTT client
    mqttConfigPush.init(client);
  });

  client.on('error', (err) => {
    logger.error('Shared MQTT client error', {
      url,
      clientId: client.options.clientId,
      err: serializeError(err)
    });
  });

  client.on('offline', () => {
    logger.warn('Shared MQTT client offline', {
      url,
      clientId: client.options.clientId
    });
    mqttClient = null;
  });

  client.on('reconnect', () => {
    logger.info('Shared MQTT client reconnecting', {
      url,
      clientId: client.options.clientId
    });
  });

  client.on('close', () => {
    logger.warn('Shared MQTT client connection closed', {
      url,
      clientId: client.options.clientId
    });
  });

  return client;
}

// Periodic MQTT health check
setInterval(() => {
  if (mqttClient) {
    logger.debug('MQTT health check', {
      connected: mqttClient.connected,
      reconnecting: mqttClient.reconnecting,
      url: process.env.MQTT_URL || 'mqtt://127.0.0.1:1883',
      clientId: mqttClient.options.clientId
    });
  } else {
    logger.debug('MQTT client not initialized');
  }
}, 30000); // Log every 30 seconds

server.listen(port, async () => {
  logger.info('Server listening', { port });
  try {
    await db.initDb();
  } catch (err) {
    logger.error('DB init failed', { err: serializeError(err) });
  }
  try {
    mqttGeofenceSync = createMqttGeofenceSync({ db, logger });
    mqttDeviceMapSync = createMqttDeviceMapSync({ db, logger });
    mqttTrackerSubscriber = createMqttTrackerSubscriber({ logger, db, broadcast });
    mqttFenceSubscriber = createMqttFenceSubscriber({ logger, db, broadcast });
    initMqttClient(); // Initialize shared MQTT for BLE locate
  } catch (err) {
    logger.error('MQTT sync init failed', { err: serializeError(err) });
  }
  try {
    await checkInfluxHealth();
    // Initialize AI analytics after InfluxDB is confirmed healthy
    try {
      aiAnalytics = new AIDevAnalytics({
        url: process.env.INFLUXDB_URL || 'http://localhost:8086',
        token: process.env.INFLUXDB_TOKEN,
        org: process.env.INFLUXDB_ORG,
        bucket: process.env.INFLUXDB_BUCKET || 'moopoint'
      });
      logger.info('AI Development Analytics initialized');
    } catch (aiErr) {
      logger.error('AI Analytics initialization failed', { err: serializeError(aiErr) });
      aiAnalytics = null;
    }
  } catch (err) {
    logger.error('Influx health check on startup failed', { err: serializeError(err) });
    aiAnalytics = null;
  }
});

let geofenceLoopRunning = false;
const geofenceIntervalMs = Math.max(5000, Number(process.env.GEOFENCE_CHECK_INTERVAL_MS || '30000'));
let _behaviorCheckCounter = 0;
const _behaviorCheckEveryN = Math.ceil(900000 / geofenceIntervalMs); // every ~15 min
setInterval(async () => {
  if (geofenceLoopRunning) return;
  geofenceLoopRunning = true;
  try {
    const nodes0 = await getLatestNodes();
    const nodes = await applyFriendlyNames(nodes0);
    await runGeofenceChecksForNodes(nodes, broadcast);
    await runVoltageChecksForNodes(nodes, broadcast);
    await runOfflineChecksForNodes(nodes, broadcast);

    // Behavior health checks every ~15 minutes (not every loop iteration)
    _behaviorCheckCounter++;
    if (_behaviorCheckCounter >= _behaviorCheckEveryN) {
      _behaviorCheckCounter = 0;
      try {
        await runBehaviorHealthChecks(nodes, broadcast);
      } catch (bhErr) {
        logger.error('Behavior health check failed', { err: serializeError(bhErr) });
      }
    }
    // Broadcast latest positions to all connected WS clients
    if (nodes.length) {
      broadcast({
        type: 'position_update',
        nodes: nodes.map(n => ({
          nodeId: n.nodeId,
          name: n.name,
          latitude: n.latitude,
          longitude: n.longitude,
          batteryLevel: n.batteryLevel,
          voltage: n.voltage,
          nodeType: n.nodeType,
          lastUpdated: n.lastUpdated,
          isNew: n.isNew,
        })),
        // For backwards compatibility with older Flutter builds
        cows: nodes.map(n => ({
          nodeId: n.nodeId,
          name: n.name,
          latitude: n.latitude,
          longitude: n.longitude,
          batteryLevel: n.batteryLevel,
          lastUpdated: n.lastUpdated,
        })),
      });
    }
  } catch (err) {
    logger.error('Geofence check loop failed', { err: serializeError(err) });
  } finally {
    geofenceLoopRunning = false;
  }
}, geofenceIntervalMs).unref();
