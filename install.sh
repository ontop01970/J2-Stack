#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# J² Stack — One-shot Installer
# Clones OpenJarvis, builds Rust ext, configures
# systemd unit, and wires Jev into Hermes.
# ──────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
J2_HOME="${J2_HOME:-$HOME/j2-stack}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[J²]${NC} $1"; }
warn()  { echo -e "${YELLOW}[J²]${NC} $1"; }
die()   { echo -e "${RED}[J²]${NC} $1" >&2; exit 1; }

# ── Prerequisites ──────────────────────────────

command -v git    >/dev/null 2>&1 || die "git is required. Install it first."
command -v python3 >/dev/null 2>&1 || die "Python 3.10+ is required."
command -v uv     >/dev/null 2>&1 || die "uv (https://docs.astral.sh/uv/) is required."

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
if [[ "$(echo "$PY_VER >= 3.10" | bc)" != "1" ]]; then
  die "Python 3.10+ required, got $PY_VER"
fi

# Check Hermes
HERMES_BIN="${HERMES_HOME}/venv/bin/hermes"
if [ ! -f "$HERMES_BIN" ]; then
  HERMES_BIN=$(command -v hermes || true)
fi
if [ -z "$HERMES_BIN" ]; then
  die "Hermes Agent not found. Install it first: https://hermes-agent.nousresearch.com"
fi
info "Found Hermes at: $HERMES_BIN"
info "J² will be installed at: $J2_HOME"

# ── Step 1: Clone / Update OpenJarvis ─────────

JARVIS_DIR="${J2_HOME}/OpenJarvis"
if [ -d "$JARVIS_DIR" ]; then
  info "OpenJarvis already cloned — pulling latest..."
  cd "$JARVIS_DIR" && git pull --ff-only
else
  info "Cloning OpenJarvis..."
  git clone https://github.com/open-jarvis/OpenJarvis.git "$JARVIS_DIR"
  cd "$JARVIS_DIR"
fi

# ── Step 2: Build + Install Jarvis ────────────

info "Setting up Python environment (uv sync)..."
uv sync --frozen

info "Building Rust extension..."
uv run maturin develop --release 2>/dev/null || {
  warn "Rust extension build skipped — check your Rust toolchain if you need it."
}

# Init DB if not present
JARVIS_DB="${HOME}/.local/share/jarvis/memory.db"
if [ ! -f "$JARVIS_DB" ]; then
  info "Initializing Jarvis memory database..."
  mkdir -p "$(dirname "$JARVIS_DB")"
  uv run python -c "
import openjarvis
openjarvis.init_db('$JARVIS_DB')
print('Database initialized.')
"
fi

# ── Step 3: Install systemd user unit ────────

info "Installing Jarvis systemd user unit..."
mkdir -p "${HOME}/.config/systemd/user/"
cp "$SCRIPT_DIR/configs/jarvis-serve.service" "${HOME}/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now jarvis-serve.service || {
  warn "Could not start jarvis-serve — will start on next login."
}
info "Jarvis API running at http://127.0.0.1:8000"

# ── Step 4: Install Jev plugin ───────────────

info "Installing Jev agent router..."
if [ -f "$HERMES_BIN" ]; then
  "$HERMES_BIN" plugin install jev 2>/dev/null || {
    warn "Jev plugin install via Hermes failed — install manually:"
    echo "  hermes plugin install jev"
  }
else
  warn "Install Jev manually: hermes plugin install jev"
fi

# ── Step 5: Activate J² profile ──────────────

J2_PROFILE_DIR="${HERMES_HOME}/profiles/j2"
if [ ! -f "$J2_PROFILE_DIR/config.yaml" ]; then
  info "Installing J² Hermes profile..."
  mkdir -p "$J2_PROFILE_DIR"
  cp "$SCRIPT_DIR/configs/hermes-profile.yaml" "$J2_PROFILE_DIR/config.yaml"
  "$HERMES_BIN" profile use j2 2>/dev/null || {
    warn "Could not auto-activate profile. Manually: hermes profile use j2"
  }
else
  info "J² profile already installed."
fi

# ── Done ──────────────────────────────────────

echo ""
info "┌─────────────────────────────────────────────────────────┐"
info "│  J² Stack installed successfully!                       │"
info "│                                                         │"
info "│  Memory backend:  Jarvis → http://127.0.0.1:8000        │"
info "│  Agent router:    Jev (plugin)                          │"
info "│  Hermes profile:  j2 (active)                           │"
info "│                                                         │"
info "│  Memory context:  Zero-Cost — nothing in your prompt    │"
info "│                   unless Jev says it's relevant.        │"
info "│                                                         │"
info "│  Next: Restart Hermes or open a new session.            │"
info "└─────────────────────────────────────────────────────────┘"