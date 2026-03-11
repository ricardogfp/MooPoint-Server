/**
 * AI-Powered Development Analytics Service
 * Automates debugging, battery estimation, range analysis, and system health monitoring
 */

const { InfluxDB } = require('@influxdata/influxdb-client');
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
  transports: [
    new winston.transports.File({ filename: 'ai-analytics.log' }),
    new winston.transports.Console({ format: winston.format.simple() })
  ]
});

class AIDevAnalytics {
  constructor(influxConfig) {
    this.influxDB = new InfluxDB({ url: influxConfig.url, token: influxConfig.token });
    this.queryApi = this.influxDB.getQueryApi(influxConfig.org);
    this.bucket = influxConfig.bucket;
    
    this.thresholds = {
      gpsFixTime: { warning: 60, critical: 120 },
      batteryDrain: { warning: 5, critical: 10 },
      rssi: { warning: -100, critical: -110 },
      snr: { warning: -5, critical: -10 },
      hmacFailRate: { warning: 0.05, critical: 0.1 },
      gpsHotStarts: { warning: 3, critical: 5 }
    };
  }

  // BATTERY LIFE ESTIMATION
  async estimateBatteryLife(nodeId, timeRange = '-24h') {
    const query = `
      from(bucket: "${this.bucket}")
        |> range(start: ${timeRange})
        |> filter(fn: (r) => r["_measurement"] == "position")
        |> filter(fn: (r) => r["node_id"] == "${nodeId}")
        |> filter(fn: (r) => r["_field"] == "batt_percent" or r["_field"] == "ext_power_mode" or r["_field"] == "ext_gps_fix_time")
        |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
    `;

    const data = await this.queryApi.collectRows(query);
    if (data.length < 2) return { error: 'Insufficient data' };

    const first = data[0], last = data[data.length - 1];
    const timeDiffHours = (new Date(last._time) - new Date(first._time)) / 3600000;
    const drainRatePerHour = (first.batt_percent - last.batt_percent) / timeDiffHours;
    const hoursRemaining = drainRatePerHour > 0 ? (last.batt_percent - 10) / drainRatePerHour : null;

    const avgGpsFixTime = data.reduce((sum, d) => sum + (d.ext_gps_fix_time || 0), 0) / data.length;
    const avgPowerMode = data.reduce((sum, d) => sum + (d.ext_power_mode || 0), 0) / data.length;

    const suggestions = [];
    if (avgGpsFixTime > 60) {
      suggestions.push({
        type: 'GPS_OPTIMIZATION',
        message: `GPS fix time ${avgGpsFixTime.toFixed(1)}s. Optimize timeout or check antenna.`,
        potentialSavings: '15-25% battery life'
      });
    }
    if (drainRatePerHour > this.thresholds.batteryDrain.critical) {
      suggestions.push({
        type: 'CRITICAL_DRAIN',
        severity: 'critical',
        message: `Abnormal drain: ${drainRatePerHour.toFixed(2)}%/hr. Check hardware.`
      });
    }

    return {
      nodeId,
      currentBattery: last.batt_percent.toFixed(1),
      drainRatePerHour: drainRatePerHour.toFixed(2),
      daysRemaining: hoursRemaining ? (hoursRemaining / 24).toFixed(1) : 'N/A',
      avgGpsFixTime: avgGpsFixTime.toFixed(1),
      healthStatus: drainRatePerHour > this.thresholds.batteryDrain.critical ? 'CRITICAL' : 'GOOD',
      suggestions
    };
  }

  // RANGE & COVERAGE ANALYSIS
  async analyzeRange(nodeId = null, timeRange = '-24h') {
    const nodeFilter = nodeId ? `|> filter(fn: (r) => r["node_id"] == "${nodeId}")` : '';
    const query = `
      from(bucket: "${this.bucket}")
        |> range(start: ${timeRange})
        |> filter(fn: (r) => r["_measurement"] == "position")
        ${nodeFilter}
        |> filter(fn: (r) => r["_field"] == "lat" or r["_field"] == "lon" or 
                             r["_field"] == "ext_tracker_rssi" or r["_field"] == "ext_tracker_snr")
        |> pivot(rowKey:["_time", "node_id"], columnKey: ["_field"], valueColumn: "_value")
    `;

    const data = await this.queryApi.collectRows(query);
    const nodeStats = {};

    data.forEach(point => {
      const nid = point.node_id;
      if (!nodeStats[nid]) {
        nodeStats[nid] = { rssiValues: [], snrValues: [], poorSignalLocations: [] };
      }
      if (point.ext_tracker_rssi) nodeStats[nid].rssiValues.push(point.ext_tracker_rssi);
      if (point.ext_tracker_snr) nodeStats[nid].snrValues.push(point.ext_tracker_snr);
      
      if (point.ext_tracker_rssi < this.thresholds.rssi.warning) {
        nodeStats[nid].poorSignalLocations.push({
          lat: point.lat, lon: point.lon, rssi: point.ext_tracker_rssi
        });
      }
    });

    const results = Object.entries(nodeStats).map(([nid, stats]) => {
      const avgRssi = stats.rssiValues.reduce((a, b) => a + b, 0) / stats.rssiValues.length;
      const recommendations = [];

      if (avgRssi < this.thresholds.rssi.warning) {
        recommendations.push({
          type: 'WEAK_SIGNAL',
          message: `Avg RSSI ${avgRssi.toFixed(1)} dBm. Add gateway or increase TX power.`
        });
      }

      return {
        nodeId: nid,
        avgRssi: avgRssi.toFixed(1),
        status: avgRssi < this.thresholds.rssi.critical ? 'CRITICAL' : 'GOOD',
        poorSignalCount: stats.poorSignalLocations.length,
        recommendations
      };
    });

    return { nodes: results };
  }

  // SYSTEM HEALTH MONITORING
  async monitorSystemHealth(timeRange = '-1h') {
    const issues = [];

    // GPS Performance Check
    const gpsQuery = `
      from(bucket: "${this.bucket}")
        |> range(start: ${timeRange})
        |> filter(fn: (r) => r["_measurement"] == "position")
        |> filter(fn: (r) => r["_field"] == "ext_gps_fix_time" or r["_field"] == "ext_gps_hot")
        |> pivot(rowKey:["_time", "node_id"], columnKey: ["_field"], valueColumn: "_value")
    `;

    const gpsData = await this.queryApi.collectRows(gpsQuery);
    const nodeGpsStats = {};

    gpsData.forEach(point => {
      const nid = point.node_id;
      if (!nodeGpsStats[nid]) nodeGpsStats[nid] = { fixTimes: [], hotStarts: [] };
      if (point.ext_gps_fix_time) nodeGpsStats[nid].fixTimes.push(point.ext_gps_fix_time);
      if (point.ext_gps_hot) nodeGpsStats[nid].hotStarts.push(point.ext_gps_hot);
    });

    Object.entries(nodeGpsStats).forEach(([nodeId, stats]) => {
      const avgFixTime = stats.fixTimes.reduce((a, b) => a + b, 0) / stats.fixTimes.length;
      const avgHotStarts = stats.hotStarts.reduce((a, b) => a + b, 0) / stats.hotStarts.length;

      if (avgFixTime > this.thresholds.gpsFixTime.critical) {
        issues.push({
          nodeId, type: 'GPS_SLOW', severity: 'critical',
          value: avgFixTime.toFixed(1) + 's',
          action: 'Check GPS antenna connection'
        });
      }
      if (avgHotStarts > this.thresholds.gpsHotStarts.warning) {
        issues.push({
          nodeId, type: 'GPS_HOT_STARTS', severity: 'warning',
          value: avgHotStarts.toFixed(1),
          action: 'GPS losing lock - check power stability'
        });
      }
    });

    return {
      timestamp: new Date().toISOString(),
      totalIssues: issues.length,
      criticalIssues: issues.filter(i => i.severity === 'critical').length,
      healthStatus: issues.some(i => i.severity === 'critical') ? 'CRITICAL' : 'HEALTHY',
      issues
    };
  }

  // GENERATE COMPREHENSIVE REPORT
  async generateDevReport(nodeId = null) {
    const [battery, range, health] = await Promise.all([
      nodeId ? this.estimateBatteryLife(nodeId) : Promise.resolve({}),
      this.analyzeRange(nodeId),
      this.monitorSystemHealth()
    ]);

    return {
      generatedAt: new Date().toISOString(),
      nodeId: nodeId || 'all',
      batteryAnalysis: battery,
      rangeAnalysis: range,
      systemHealth: health,
      summary: {
        overallHealth: health.healthStatus,
        criticalIssues: health.criticalIssues
      }
    };
  }
}

module.exports = AIDevAnalytics;