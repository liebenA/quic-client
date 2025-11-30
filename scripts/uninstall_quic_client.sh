#!/usr/bin/env bash
set -euo pipefail

# ==== 0) Must run as root ====
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[ERROR] Run this uninstaller as root (sudo)."
  exit 1
fi

# ==== 1) OS detection (Linux / macOS) ====
OS_NAME="$(uname -s 2>/dev/null || echo "unknown")"
IS_MACOS=0
if [[ "${OS_NAME}" == "Darwin" ]]; then
  IS_MACOS=1
fi

echo "[INFO] Detected OS: ${OS_NAME}"

# ==== 2) Standard paths ====
REPO_DIR="/opt/quic-client"
BIN_TARGET="/usr/local/bin/quic-client"
BATCH_SCRIPT="/usr/local/bin/quic-client-batch.sh"
LOG_DIR="/var/log/quic-client"

# ==== 3) Remove crontab entry (root) ====
echo "[INFO] Removing root crontab entry for quic-client ..."
# Works on both Linux & macOS (Darwin)
( crontab -l 2>/dev/null | grep -v 'quic-client-batch.sh' || true ) | crontab - || true

# ==== 4) Remove batch script ====
echo "[INFO] Deleting batch script ..."
rm -f "${BATCH_SCRIPT}" || true

# ==== 5) Remove binary ====
if [[ -x "${BIN_TARGET}" ]]; then
  echo "[INFO] Removing binary ${BIN_TARGET}"
  rm -f "${BIN_TARGET}" || true
else
  echo "[INFO] Binary not found at ${BIN_TARGET} (already removed?)"
fi

# ==== 6) Remove sources ====
if [[ -d "${REPO_DIR}" ]]; then
  echo "[INFO] Removing repository directory ${REPO_DIR}"
  rm -rf "${REPO_DIR}" || true
else
  echo "[INFO] Repository directory ${REPO_DIR} not found (already removed?)"
fi

# ==== 7) Optional: log cleanup ====
# Uncomment if you want to remove logs
# rm -rf "${LOG_DIR}"

echo "[INFO] Uninstall complete."
echo "       Binary    : ${BIN_TARGET} (removed)"
echo "       Batch     : ${BATCH_SCRIPT} (removed)"
echo "       Repo      : ${REPO_DIR} (removed)"
echo "       Crontab   : entry cleaned"
echo "       Logs kept : ${LOG_DIR}"
