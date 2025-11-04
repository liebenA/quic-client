#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/liebenA/quic-client"
INSTALL_PREFIX="${INSTALL_PREFIX:-$HOME/.local}"
BIN_DIR="${BIN_DIR:-$(go env GOPATH 2>/dev/null || echo $HOME/go)/bin}"
SCRIPTS_DIR="$HOME/.local/bin"
LOG_DIR="$HOME/.quic-client/logs"

# 0) Prérequis minimaux
command -v git >/dev/null 2>&1 || { echo "git not found in PATH"; exit 1; }
command -v go  >/dev/null 2>&1 || { echo "go not found in PATH"; exit 1; }

# 1) Cloner ou mettre à jour (si déjà présent)
if [[ ! -d "$HOME/quic-client" ]]; then
  git clone "$REPO_URL" "$HOME/quic-client"
else
  git -C "$HOME/quic-client" pull --ff-only
fi

cd "$HOME/quic-client"

# 2) Construire et installer
go mod tidy
go build ./...
go install ./...

mkdir -p "$SCRIPTS_DIR" "$LOG_DIR"

# 3) Déployer le batch script dans ~/.local/bin
install -m 0755 scripts/quic-client-batch.sh "$SCRIPTS_DIR/quic-client-batch.sh"

# 4) Premier run
"$SCRIPTS_DIR/quic-client-batch.sh" || true

# 5) Cron toutes les 2h (au top de l’heure paire)
CRON_LINE='0 */2 * * * /bin/bash -lc "~/.local/bin/quic-client-batch.sh"'
# éviter les doublons
( crontab -l 2>/dev/null | grep -v 'quic-client-batch.sh' ; echo "$CRON_LINE" ) | crontab -

echo "Install OK."
echo "Binary: $(command -v quic-client || echo "$BIN_DIR/quic-client")"
echo "Batch:  $SCRIPTS_DIR/quic-client-batch.sh"
echo "Logs:   $LOG_DIR"
echo "Cron:   $(crontab -l | grep quic-client-batch.sh || true)"
