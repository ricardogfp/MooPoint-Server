const AIDevAnalytics = require('../src/ai_dev_analytics');
require('dotenv').config();

const analytics = new AIDevAnalytics({
  url: process.env.INFLUXDB_URL,
  token: process.env.INFLUXDB_TOKEN,
  org: process.env.INFLUXDB_ORG,
  bucket: process.env.INFLUXDB_BUCKET
});

async function runMonitoring() {
  console.log('\n=== MooPoint Development Monitor ===\n');
  
  const report = await analytics.generateDevReport();
  
  console.log(`Overall Health: ${report.summary.overallHealth}`);
  console.log(`Critical Issues: ${report.summary.criticalIssues}\n`);
  
  if (report.systemHealth.issues.length > 0) {
    console.log('🚨 ISSUES DETECTED:');
    report.systemHealth.issues.forEach(issue => {
      console.log(`  [${issue.severity.toUpperCase()}] Node ${issue.nodeId}: ${issue.type}`);
      console.log(`    → ${issue.action}\n`);
    });
  }
  
  if (report.rangeAnalysis.nodes) {
    console.log('📡 RANGE ANALYSIS:');
    report.rangeAnalysis.nodes.forEach(node => {
      console.log(`  Node ${node.nodeId}: RSSI ${node.avgRssi} dBm (${node.status})`);
      node.recommendations.forEach(rec => console.log(`    → ${rec.message}`));
    });
  }
}

// Run every 5 minutes
setInterval(runMonitoring, 5 * 60 * 1000);
runMonitoring(); // Run immediately