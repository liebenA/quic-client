#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-$HOME/quic-client/config/client.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

LOG_DIR="$HOME/.quic-client/logs"
BIN_PATH="$(command -v quic-client || echo "$(go env GOPATH)/bin/quic-client")"

mkdir -p "$LOG_DIR"

# Format: cron-YYYYMMDD-HHMM.log (UTC)
LOG_FILE="$LOG_DIR/cron-$(date -u +%Y%m%d-%H%M).log"

{
  echo "------------------------------------------------------------"
  echo "[QUIC CLIENT BATCH] Started at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "Using binary: $BIN_PATH"
  echo "------------------------------------------------------------"

  # Run tests sequentially
  "$BIN_PATH" -u emes.bj -p 4447 -n 1  -d 65536
  "$BIN_PATH" -u emes.bj -p 4447 -n 5  -d 262144
  "$BIN_PATH" -u emes.bj -p 4447 -n 30 -d 262144

  echo "------------------------------------------------------------"
  echo "[DONE] Completed at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "------------------------------------------------------------"
} >> "$LOG_FILE" 2>&1

