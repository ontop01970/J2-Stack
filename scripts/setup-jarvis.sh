#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# J² Stack — setup-jarvis.sh
# Standalone: clones + builds OpenJarvis
# ──────────────────────────────────────────────
# Run from the j2-stack root:
#   bash scripts/setup-jarvis.sh

J2_HOME="${J2_HOME:-$HOME/j2-stack}"
JARVIS_DIR="${J2_HOME}/OpenJarvis"

info() { echo -e "\033[0;32m[J²/Jarvis]\033[0m $1"; }
warn() { echo -e "\033[1;33m[J²/Jarvis]\033[0m $1"; }

command -v git     >/dev/null 2>&1 || { echo "git required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required"; exit 1; }
command -v uv      >/dev/null 2>&1 || { echo "uv required"; exit 1; }

if [ -d "$JARVIS_DIR" ]; then
  info "Pulling latest OpenJarvis..."
  cd "$JARVIS_DIR" && git pull --ff-only
else
  info "Cloning OpenJarvis..."
  git clone https://github.com/your-org/OpenJarvis.git "$JARVIS_DIR"
  cd "$JARVIS_DIR"
fi

info "Building Python environment..."
uv sync --frozen

info "Building Rust extension (if applicable)..."
uv run maturin develop --release 2>/dev/null || warn "Rust build skipped"

JARVIS_DB="${HOME}/.local/share/jarvis/memory.db"
if [ ! -f "$JARVIS_DB" ]; then
  info "Initializing database..."
  mkdir -p "$(dirname "$JARVIS_DB")"
  uv run python -c "import openjarvis; openjarvis.init_db('$JARVIS_DB')"
fi

mkdir -p "${HOME}/.config/systemd/user/"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cp "$SCRIPT_DIR/configs/jarvis-serve.service" "${HOME}/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now jarvis-serve.service 2>/dev/null || warn "Service start deferred"

info "Jarvis ready at http://127.0.0.1:8000"