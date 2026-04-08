#!/bin/bash
set -euo pipefail

# First-time setup: install Claude Code if not present
if ! command -v claude &>/dev/null; then
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
fi

# First-time setup: install Python dependencies if .venv missing
if [ ! -d "/workspace/.venv" ]; then
    echo "Installing Python dependencies..."
    cd /workspace && uv sync --frozen
fi

# Initialize firewall
FIREWALL_MODE="${FIREWALL_MODE:-strict}"
if [[ "$FIREWALL_MODE" == "open" ]]; then
    sudo /usr/local/bin/init-firewall.sh --allow-https
else
    sudo /usr/local/bin/init-firewall.sh
fi

exec sleep infinity
