#!/usr/bin/env bash
set -euo pipefail

# ==== 0) OS detection (Linux / macOS) ====
OS_NAME="$(uname -s 2>/dev/null || echo "unknown")"
IS_MACOS=0

if [[ "${OS_NAME}" == "Darwin" ]]; then
  IS_MACOS=1
fi

# ==== 1) Log directory ====
LOG_DIR="/var/log/quic-client"
mkdir -p "${LOG_DIR}"

# Log file with UTC date + hour + minutes
TS="$(date -u +%Y%m%d_%H%M)"
LOG_FILE="${LOG_DIR}/cron-${TS}.log"

# Capture all output (stdout + stderr) to log file
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date -u '+%F %T UTC') - Starting quic-client batch (OS=${OS_NAME})"

# ==== 2) Binary path ====
CLIENT_BIN="/usr/local/bin/quic-client"

if [[ ! -x "${CLIENT_BIN}" ]]; then
  echo "[ERROR] quic-client not found or not executable at ${CLIENT_BIN}"
  exit 1
fi

# ==== 3) Target and parameters ====
HOST="emes.bj"
PORT="4447"

# ==== 4) Run tests ====
set +e  # continue even if a test fails, but log return codes

"${CLIENT_BIN}" -u "${HOST}" -p "${PORT}" -n 1  -d 65536
RC1=$?

"${CLIENT_BIN}" -u "${HOST}" -p "${PORT}" -n 5  -d 262144
RC2=$?

"${CLIENT_BIN}" -u "${HOST}" -p "${PORT}" -n 30 -d 262144
RC3=$?

set -e

if [[ $RC1 -ne 0 || $RC2 -ne 0 || $RC3 -ne 0 ]]; then
  echo "[WARN] One or more tests failed: rc=(${RC1},${RC2},${RC3})"
else
  echo "[INFO] All tests completed successfully."
fi

echo "[INFO] $(date -u '+%F %T UTC') - Batch finished; log: ${LOG_FILE}"
