#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-$HOME/quic-client/config/client.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi


# Defaults
HOST="${HOST:-emes.bj}"
PORT="${PORT:-4447}"

# Tests par défaut (modifiable via env)
T1_N="${T1_N:-1}"
T1_D="${T1_D:-65536}"

T2_N="${T2_N:-5}"
T2_D="${T2_D:-262144}"

T3_N="${T3_N:-30}"
T3_D="${T3_D:-262144}"

LOG_DIR="${LOG_DIR:-$HOME/.quic-client/logs}"
BIN_DIR="${BIN_DIR:-$(go env GOPATH 2>/dev/null || echo $HOME/go)/bin}"
CLIENT_BIN="${CLIENT_BIN:-$BIN_DIR/quic-client}"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cron-$(date -u +%Y%m%d).log"

exec >>"$LOG_FILE" 2>&1

echo "[$(date -u +'%F %T')] Starting batch…"

if [[ ! -x "$CLIENT_BIN" ]]; then
  echo "ERROR: quic-client not found at $CLIENT_BIN"
  exit 1
fi

set -x
"$CLIENT_BIN" -u "$HOST" -p "$PORT" -n "$T1_N" -d "$T1_D"
"$CLIENT_BIN" -u "$HOST" -p "$PORT" -n "$T2_N" -d "$T2_D"
"$CLIENT_BIN" -u "$HOST" -p "$PORT" -n "$T3_N" -d "$T3_D"
set +x

echo "[$(date -u +'%F %T')] Batch done."
