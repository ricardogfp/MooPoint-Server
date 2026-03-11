const booleanPointInPolygon = require('@turf/boolean-point-in-polygon').default;
const { point, feature } = require('@turf/helpers');

function parseGeoJsonPolygon(geojsonStr) {
  const parsed = JSON.parse(geojsonStr);

  if (parsed && parsed.type === 'Feature') {
    const geom = parsed.geometry;
    if (!geom || (geom.type !== 'Polygon' && geom.type !== 'MultiPolygon')) {
      throw new Error('invalid_geojson');
    }
    return parsed;
  }

  if (parsed && (parsed.type === 'Polygon' || parsed.type === 'MultiPolygon')) {
    return feature(parsed);
  }

  throw new Error('invalid_geojson');
}

function isInsidePolygon(lat, lon, geojsonStr) {
  const f = parseGeoJsonPolygon(geojsonStr);
  const p = point([Number(lon), Number(lat)]);
  return booleanPointInPolygon(p, f, { ignoreBoundary: false });
}

async function runGeofenceExitCheck({ nodes, assignmentsByNodeId, db, broadcast, logger }) {
  const now = new Date().toISOString();

  for (const node of nodes) {
    const nodeKey = String(node.nodeId);
    const assigned = assignmentsByNodeId[nodeKey] || [];

    for (const fence of assigned) {
      let insideNow = 0;
      try {
        insideNow = isInsidePolygon(node.latitude, node.longitude, fence.geojson);
      } catch (e) {
        logger.error('Geofence evaluation failed', { nodeId: node.nodeId, geofenceId: fence.id, err: e });
        continue;
      }

      const prev = await db.getGeofenceState(fence.id, node.nodeId);
      if (!prev) {
        await db.setGeofenceState(fence.id, node.nodeId, insideNow, now);
        continue;
      }

      const wasInside = prev.isInside === 1;

      if (wasInside && !insideNow) {
        // Exit event
        logger.info('Geofence exit detected', { nodeId: node.nodeId, geofenceId: fence.id });
        const eventId = await db.insertGeofenceEvent({
          geofenceId: fence.id,
          nodeId: node.nodeId,
          type: 'exit',
          eventTime: now,
          lat: node.latitude,
          lon: node.longitude,
        });
        await db.setGeofenceState(fence.id, node.nodeId, insideNow, now);

        broadcast({
          type: 'geofence_exit',
          eventId,
          geofenceId: fence.id,
          geofenceName: fence.name,
          nodeId: node.nodeId,
          nodeName: node.name,
          eventTime: now,
          latitude: node.latitude,
          longitude: node.longitude,
        });
      } else if (!wasInside && insideNow) {
        // Entry event
        logger.info('Geofence entry detected', { nodeId: node.nodeId, geofenceId: fence.id });
        await db.insertGeofenceEvent({
          geofenceId: fence.id,
          nodeId: node.nodeId,
          type: 'entry',
          eventTime: now,
          lat: node.latitude,
          lon: node.longitude,
        });
        await db.setGeofenceState(fence.id, node.nodeId, insideNow, now);

        broadcast({
          type: 'geofence_entry',
          geofenceId: fence.id,
          geofenceName: fence.name,
          nodeId: node.nodeId,
          nodeName: node.name,
          eventTime: now,
        });
      }
    }
  }
}

module.exports = {
  parseGeoJsonPolygon,
  isInsidePolygon,
  runGeofenceExitCheck,
};
