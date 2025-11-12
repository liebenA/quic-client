#!/usr/bin/env bash
set -euo pipefail

# Où écrire les logs
LOG_DIR="/var/log/quic-client"
mkdir -p "${LOG_DIR}"

# Fichier de log avec date + heure + minutes (UTC)
TS="$(date -u +%Y%m%d_%H%M)"
LOG_FILE="${LOG_DIR}/cron-${TS}.log"

# Capturer toute la sortie
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[INFO] $(date -u '+%F %T UTC') - Starting quic-client batch"

# Chemin binaire
CLIENT_BIN="/usr/local/bin/quic-client"
if ! command -v "${CLIENT_BIN}" >/dev/null 2>&1; then
  echo "[ERROR] quic-client not found at ${CLIENT_BIN}"
  exit 1
fi

# Cible et paramètres
HOST="emes.bj"
PORT="4447"

set +e  # on continue même si un test échoue, mais on log
"${CLIENT_BIN}" -u "${HOST}" -p "${PORT}" -n 1  -d 65536
RC1=$?
"${CLIENT_BIN}" -u "${HOST}" -p "${PORT}" -n 5  -d 262144
RC2=$?
"${CLIENT_BIN}" -u "${HOST}" -p "${PORT}" -n 30 -d 262144
RC3=$?
set -e

if [[ $RC1 -ne 0 || $RC2 -ne 0 || $RC3 -ne 0 ]]; then
  echo "[WARN] One or more tests failed: rc=($RC1,$RC2,$RC3)"
else
  echo "[INFO] All tests completed successfully."
fi

echo "[INFO] $(date -u '+%F %T UTC') - Batch finished; log: ${LOG_FILE}"
