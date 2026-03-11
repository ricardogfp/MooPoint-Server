module.exports = {
  apps: [{
    name: "mqtt-test",
    script: "server/scripts/mqtt_test.js",
    args: ["--interval", "300000", "--fence-interval", "60000"],
    watch: false,
    restart_on_failure: true,
    max_restarts: 10,
    min_uptime: "5s"
  }]
};
