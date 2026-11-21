#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# J² Stack — setup-jev.sh
# Standalone: installs Jev agent router for Hermes
# ──────────────────────────────────────────────

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_BIN="${HERMES_HOME}/venv/bin/hermes"
[ ! -f "$HERMES_BIN" ] && HERMES_BIN=$(command -v hermes || true)

info() { echo -e "\033[0;32m[J²/Jev]\033[0m $1"; }
warn() { echo -e "\033[1;33m[J²/Jev]\033[0m $1"; }

if [ -z "$HERMES_BIN" ]; then
  echo "[J²/Jev] Hermes not found. Install it first: https://hermes-agent.nousresearch.com"
  exit 1
fi

info "Installing Jev plugin..."
"$HERMES_BIN" plugin install jev 2>/dev/null || {
  warn "Plugin install failed. Try: hermes plugin install jev"
  exit 1
}

info "Jev agent router installed."
info "Activate with: hermes profile use j2"