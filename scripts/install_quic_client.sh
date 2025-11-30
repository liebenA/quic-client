#!/usr/bin/env bash
set -euo pipefail

# ==== 0) Requirement: must be run as root ====
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[ERROR] This installer must be run as root (sudo)."
  exit 1
fi

# ==== 1) OS detection & preparation ====
OS_NAME="$(uname -s 2>/dev/null || echo "unknown")"
IS_MACOS=0

PKG=""
INSTALL_CMD=""
CRON_SERVICE=""

if [[ "${OS_NAME}" == "Darwin" ]]; then
  # ----- macOS (Apple Silicon / Intel) -----
  IS_MACOS=1
  echo "[INFO] Detected macOS (Darwin). Using Homebrew as package manager."

  if ! command -v brew >/dev/null 2>&1; then
    echo "[ERROR] Homebrew (brew) is not installed. Please install Homebrew (https://brew.sh) and run this installer again."
    exit 1
  fi

  PKG="brew"
  INSTALL_CMD="brew install"
  # cron exists on macOS; we do not manage any cron service here.
  CRON_SERVICE="cron"

else
  # ----- Linux path using /etc/os-release -----
  # shellcheck disable=SC1091
  source /etc/os-release || true
  ID_LIKE_LOWER="$(echo "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')"
  ID_LOWER="$(echo "${ID:-}" | tr '[:upper:]' '[:lower:]')"

  case "${ID_LOWER}:${ID_LIKE_LOWER}" in
    *"debian"*:*|*"ubuntu"*:*|*:"debian"*|*:"ubuntu"*)
      PKG="apt-get"
      INSTALL_CMD="apt-get update -y && apt-get install -y"
      CRON_SERVICE="cron"
      ;;
    *"rhel"*:*|*"centos"*:*|*"rocky"*:*|*"almalinux"*:*|*"amzn"*:*|*:"rhel"*|*:"fedora"*)
      # dnf or yum
      if command -v dnf >/dev/null 2>&1; then
        PKG="dnf"
        INSTALL_CMD="dnf install -y"
      else
        PKG="yum"
        INSTALL_CMD="yum install -y"
      fi
      CRON_SERVICE="crond"
      ;;
    *"fedora"*:*|*"fedora":*)
      PKG="dnf"
      INSTALL_CMD="dnf install -y"
      CRON_SERVICE="crond"
      ;;
    *"arch"*:*|*"manjaro"*:*|*:"arch"*)
      PKG="pacman"
      INSTALL_CMD="pacman -Sy --noconfirm"
      CRON_SERVICE="cronie"
      ;;
    *"suse"*:*|*"opensuse"*:*|*:"suse"*|*:"opensuse"*)
      PKG="zypper"
      INSTALL_CMD="zypper install -y"
      CRON_SERVICE="cron"
      ;;
    *)
      echo "[WARN] Unknown distro (${ID_LOWER}); attempting generic paths."
      # Last resort: try apt, then dnf, then yum, then pacman
      if command -v apt-get >/dev/null 2>&1; then
        PKG="apt-get"
        INSTALL_CMD="apt-get update -y && apt-get install -y"
        CRON_SERVICE="cron"
      elif command -v dnf >/dev/null 2>&1; then
        PKG="dnf"
        INSTALL_CMD="dnf install -y"
        CRON_SERVICE="crond"
      elif command -v yum >/dev/null 2>&1; then
        PKG="yum"
        INSTALL_CMD="yum install -y"
        CRON_SERVICE="crond"
      elif command -v pacman >/dev/null 2>&1; then
        PKG="pacman"
        INSTALL_CMD="pacman -Sy --noconfirm"
        CRON_SERVICE="cronie"
      else
        echo "[ERROR] No supported package manager found."
        exit 1
      fi
      ;;
  esac
fi

# ==== 2) Standard variables ====
REPO_URL="https://github.com/liebenA/quic-client"
REPO_DIR="/opt/quic-client"
BIN_TARGET="/usr/local/bin/quic-client"
BATCH_SCRIPT="/usr/local/bin/quic-client-batch.sh"
LOG_DIR="/var/log/quic-client"

# ==== 3) Install git, go, cron depending on OS/distro ====
echo "[INFO] Installing prerequisites with ${PKG} ..."
case "${PKG}" in
  apt-get)
    bash -c "${INSTALL_CMD} git golang cron"
    ;;
  dnf|yum)
    bash -c "${INSTALL_CMD} git golang cronie"
    ;;
  pacman)
    bash -c "${INSTALL_CMD} git go cronie"
    ;;
  zypper)
    bash -c "${INSTALL_CMD} git go cron"
    ;;
  brew)
    # macOS (Apple Silicon / Intel)
    bash -c "${INSTALL_CMD} git go"
    ;;
  *)
    echo "[WARN] No package installation rules defined for PKG='${PKG}'. Skipping automatic prerequisite installation."
    ;;
esac

# Binary checks
command -v git >/dev/null 2>&1 || { echo "[ERROR] git not found after install"; exit 1; }
command -v go  >/dev/null 2>&1 || { echo "[ERROR] go not found after install"; exit 1; }

# ==== 4) Enable/start cron service (Linux only) ====
if [[ "${IS_MACOS}" -eq 1 ]]; then
  echo "[INFO] macOS detected: cron/launchd is managed by the system. No cron service will be enabled."
else
  echo "[INFO] Enabling and starting cron service: ${CRON_SERVICE}"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable "${CRON_SERVICE}" --now || true
    systemctl start "${CRON_SERVICE}" || true
  else
    # Systems without systemd: best-effort
    service "${CRON_SERVICE}" start || true
  fi
fi

# ==== 5) Fetch or update repository ====
echo "[INFO] Fetching repository to ${REPO_DIR}"
if [[ ! -d "${REPO_DIR}" ]]; then
  git clone "${REPO_URL}" "${REPO_DIR}"
else
  git -C "${REPO_DIR}" pull --ff-only || echo "[WARN] git pull failed; using existing sources"
fi
cd "${REPO_DIR}"

# ==== 6) Build & install ====
echo "[INFO] go mod tidy ..."
go mod tidy

echo "[INFO] go build ..."
go build ./...

echo "[INFO] go install ..."
go install ./...

# Retrieve compiled binary from GOPATH
GOBIN_DEFAULT="$(go env GOPATH 2>/dev/null || echo /root/go)/bin/quic-client"
if [[ -x "${GOBIN_DEFAULT}" ]]; then
  install -m 0755 "${GOBIN_DEFAULT}" "${BIN_TARGET}"
else
  # Fallback: if Go produced the binary in the repository
  if [[ -x "${REPO_DIR}/quic-client" ]]; then
    install -m 0755 "${REPO_DIR}/quic-client" "${BIN_TARGET}"
  fi
fi

if [[ ! -x "${BIN_TARGET}" ]]; then
  echo "[ERROR] Unable to place quic-client to ${BIN_TARGET}"
  exit 1
fi
echo "[INFO] Binary installed at ${BIN_TARGET}"

# ==== 7) Install batch script & logs ====
mkdir -p "${LOG_DIR}"
install -m 0755 "${REPO_DIR}/scripts/quic-client-batch.sh" "${BATCH_SCRIPT}"

# ==== 8) First run (with clean logs) ====
echo "[INFO] Running initial batch test ..."
if ! "${BATCH_SCRIPT}"; then
  echo "[WARN] Initial batch failed. Check logs in ${LOG_DIR}"
fi

# ==== 9) Crontab: every 2 hours (root) ====
echo "[INFO] Installing crontab entry (root)..."
CRON_LINE='0 */2 * * * /usr/local/bin/quic-client-batch.sh'
# Remove duplicates then add
( crontab -l 2>/dev/null | grep -v 'quic-client-batch.sh' || true ) | crontab -
( crontab -l 2>/dev/null; echo "${CRON_LINE}" ) | crontab -

echo "[INFO] Done."
echo "  Binary : ${BIN_TARGET}"
echo "  Batch  : ${BATCH_SCRIPT}"
echo "  Logs   : ${LOG_DIR}"
echo "  Cron   : $(crontab -l | grep quic-client-batch.sh || echo 'NOT FOUND')"
