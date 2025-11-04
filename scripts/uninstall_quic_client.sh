#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$HOME/.local/bin"
LOG_DIR="$HOME/.quic-client/logs"

# Remove cron line
crontab -l 2>/dev/null | grep -v 'quic-client-batch.sh' | crontab - || true

# Remove script
rm -f "$SCRIPTS_DIR/quic-client-batch.sh"

echo "Uninstall done. You can remove logs at: $LOG_DIR (optional)."
