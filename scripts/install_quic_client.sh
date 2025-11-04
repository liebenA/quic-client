#!/usr/bin/env bash
set -euo pipefail

# ---- Safety Check ----
if [[ "$EUID" -eq 0 ]]; then
  echo "Please do NOT run this script as root."
  exit 1
fi


# ----------------------------
# CONFIGURATION DE BASE
# ----------------------------
REPO_URL="https://github.com/liebenA/quic-client"
INSTALL_PREFIX="${INSTALL_PREFIX:-$HOME/.local}"
BIN_DIR="${BIN_DIR:-$(go env GOPATH 2>/dev/null || echo $HOME/go)/bin}"
SCRIPTS_DIR="$INSTALL_PREFIX/bin"
LOG_DIR="$HOME/.quic-client/logs"
REPO_DIR="$HOME/quic-client"

# ----------------------------
# FONCTIONS UTILITAIRES
# ----------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ----------------------------
# 0) CONTRÔLES PRÉALABLES
# ----------------------------
info "Checking prerequisites..."

command -v git >/dev/null 2>&1 || error "git not found in PATH. Please install git."
command -v go  >/dev/null 2>&1 || error "go not found in PATH. Please install Go (https://go.dev/doc/install)."

info "Git version: $(git --version)"
info "Go version:  $(go version)"

# ----------------------------
# 1) CLONAGE OU MISE À JOUR
# ----------------------------
if [[ ! -d "$REPO_DIR" ]]; then
  info "Cloning repository from $REPO_URL..."
  git clone "$REPO_URL" "$REPO_DIR" || error "Failed to clone repository."
else
  info "Repository already exists. Pulling latest changes..."
  git -C "$REPO_DIR" pull --ff-only || warn "Unable to update repository, continuing with existing files."
fi

cd "$REPO_DIR" || error "Failed to enter repository directory."

# ----------------------------
# 2) BUILD DU CLIENT
# ----------------------------
info "Running Go dependency tidy..."
if ! go mod tidy; then
  error "go mod tidy failed."
fi

info "Building the project..."
if ! go build ./...; then
  error "Build failed. Check for syntax or module errors."
fi

info "Installing the binary..."
if ! go install ./...; then
  error "Installation failed. Make sure GOPATH is correctly configured."
fi

# Vérification de l’installation
if [[ ! -x "$BIN_DIR/quic-client" ]]; then
  error "Binary not found at $BIN_DIR/quic-client after installation."
fi

info "Binary successfully installed at: $BIN_DIR/quic-client"

# ----------------------------
# 3) INSTALLATION DES SCRIPTS
# ----------------------------
info "Preparing directories..."
mkdir -p "$SCRIPTS_DIR" "$LOG_DIR" || error "Failed to create directories."

if [[ -f "scripts/quic-client-batch.sh" ]]; then
  install -m 0755 scripts/quic-client-batch.sh "$SCRIPTS_DIR/quic-client-batch.sh"
  info "Batch script deployed to: $SCRIPTS_DIR/quic-client-batch.sh"
else
  warn "Batch script not found in repository (scripts/quic-client-batch.sh)."
fi

# ----------------------------
# 4) PREMIER TEST
# ----------------------------
info "Running first batch test..."
if ! "$SCRIPTS_DIR/quic-client-batch.sh"; then
  warn "First test encountered an error — please check logs at $LOG_DIR"
else
  info "Initial test completed successfully."
fi

# ----------------------------
# 5) CRONJOB CONFIGURATION
# ----------------------------
info "Configuring cron job (every 2 hours)..."
#CRON_LINE='0 */2 * * * /bin/bash -lc "~/.local/bin/quic-client-batch.sh"'
CRON_LINE='0 */2 * * * bash -lc "/home/$USER/.local/bin/quic-client-batch.sh"'
( crontab -l 2>/dev/null | grep -v 'quic-client-batch.sh' ; echo "$CRON_LINE" ) | crontab -

# Supprimer les anciennes lignes similaires
( crontab -l 2>/dev/null | grep -v 'quic-client-batch.sh' || true ) | crontab -
# Ajouter la nouvelle ligne
( crontab -l 2>/dev/null; echo "$CRON_LINE" ) | crontab -

info "Cron job added. You can verify with: crontab -l"

# ----------------------------
# 6) RÉSUMÉ
# ----------------------------
echo -e "\n${GREEN}Installation completed successfully!${NC}"
echo "------------------------------------------------------"
echo "Binary:  $(command -v quic-client || echo "$BIN_DIR/quic-client")"
echo "Batch:   $SCRIPTS_DIR/quic-client-batch.sh"
echo "Logs:    $LOG_DIR"
echo "Cron:    $(crontab -l | grep quic-client-batch.sh || echo 'Not found')"
echo "------------------------------------------------------"
echo -e "${YELLOW}Next scheduled run will occur within 2 hours.${NC}"
echo "To view logs later, run: tail -f ~/.quic-client/logs/cron-\$(date -u +%Y%m%d).log"

