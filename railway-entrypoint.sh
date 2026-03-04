#!/bin/sh
# Railway entrypoint: seed config, then start the gateway.
#
# On a fresh Railway deploy there is no openclaw.json, which causes the gateway
# to crash when binding to 0.0.0.0 (lan) because controlUi.allowedOrigins is
# unset. This script creates the config file before launching the gateway.
set -e

# Resolve state dir — honour both OPENCLAW_ and legacy CLAWDBOT_ env prefixes.
STATE_DIR="${OPENCLAW_STATE_DIR:-${CLAWDBOT_STATE_DIR:-/data}}"
CONFIG_FILE="$STATE_DIR/openclaw.json"

mkdir -p "$STATE_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "railway-entrypoint: seeding $CONFIG_FILE"
  cat > "$CONFIG_FILE" <<'EOF'
{
  "gateway": {
    "mode": "local",
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    }
  }
}
EOF
else
  # Patch existing config if the flag is not already set.
  node -e "
    const fs = require('fs');
    const p = '$CONFIG_FILE';
    const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
    let changed = false;
    if (!cfg.gateway) { cfg.gateway = {}; changed = true; }
    if (!cfg.gateway.controlUi) { cfg.gateway.controlUi = {}; changed = true; }
    if (cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback !== true) {
      cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true;
      changed = true;
    }
    if (changed) {
      fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
      console.log('railway-entrypoint: patched config');
    }
  " || echo "railway-entrypoint: patch skipped (non-fatal)"
fi

export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_CONFIG_PATH="$CONFIG_FILE"

PORT="${PORT:-8080}"
echo "railway-entrypoint: starting gateway on port $PORT"
exec node openclaw.mjs gateway --allow-unconfigured --port "$PORT" --bind lan
