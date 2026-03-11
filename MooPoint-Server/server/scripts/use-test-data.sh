#!/usr/bin/env bash
# Switch the MooPoint server to the TEST InfluxDB bucket and restart.
# Run: bash server/scripts/use-test-data.sh [--env /path/to/.env] [--pm2-name <name>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/../.env}"
PM2_NAME="${PM2_NAME:-mooPoint-server}"

# Allow --env and --pm2-name flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)      ENV_FILE="$2"; shift 2 ;;
    --pm2-name) PM2_NAME="$2"; shift 2 ;;
    *) shift ;;
  esac
done

ENV_FILE="$(realpath "$ENV_FILE")"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env file not found: $ENV_FILE"
  exit 1
fi

# Patch INFLUXDB_BUCKET
if grep -q '^INFLUXDB_BUCKET=' "$ENV_FILE"; then
  sed -i 's/^INFLUXDB_BUCKET=.*/INFLUXDB_BUCKET=moopoint_test/' "$ENV_FILE"
else
  echo 'INFLUXDB_BUCKET=moopoint_test' >> "$ENV_FILE"
fi

echo "✅ INFLUXDB_BUCKET set to moopoint_test in $ENV_FILE"

# Restart via PM2 if available
if command -v pm2 &>/dev/null; then
  pm2 restart "$PM2_NAME" && echo "✅ PM2 process '$PM2_NAME' restarted." \
    || echo "⚠️  PM2 restart failed — restart the server manually."
else
  echo "⚠️  pm2 not found — restart the Node.js server manually."
fi

echo ""
echo "📋 Now using: moopoint_test (test data)"
echo "   Run the test script:  node server/scripts/mqtt_test.js --interval 10000"
echo "   Reset test data:      node server/scripts/reset-test-data.js"
echo "   Switch back to real:  bash server/scripts/use-real-data.sh"
