#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[ERROR] Run this uninstaller as root (sudo)."
  exit 1
fi

REPO_DIR="/opt/quic-client"
BIN_TARGET="/usr/local/bin/quic-client"
BATCH_SCRIPT="/usr/local/bin/quic-client-batch.sh"
LOG_DIR="/var/log/quic-client"

echo "[INFO] Removing root crontab entry ..."
( crontab -l 2>/dev/null | grep -v 'quic-client-batch.sh' || true ) | crontab - || true

echo "[INFO] Deleting batch script ..."
rm -f "${BATCH_SCRIPT}" || true

# Optionnel : supprimer le binaire
if [[ -x "${BIN_TARGET}" ]]; then
  echo "[INFO] Removing binary ${BIN_TARGET}"
  rm -f "${BIN_TARGET}"
fi

# Optionnel : supprimer les sources (décommenter si souhaité)
if [[ -d "${REPO_DIR}" ]]; then
  echo "[INFO] Removing sources in ${REPO_DIR}"
  rm -rf "${REPO_DIR}"
fi

# Optionnel : garder les logs, ou nettoyer :
# rm -rf "${LOG_DIR}"

echo "[INFO] Uninstall complete."
