#!/bin/bash
set -euo pipefail

# Set up git identity from environment variables
if [ -n "${GIT_USER_NAME:-}" ]; then
    git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
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
