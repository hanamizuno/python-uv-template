#!/usr/bin/env bash
set -euo pipefail

uv sync --frozen

if ! command -v codex >/dev/null 2>&1; then
  sudo npm install -g @openai/codex
fi

mkdir -p "$HOME/.codex"

if [ ! -f "$HOME/.codex/config.toml" ]; then
  cp .devcontainer/codex-config.toml "$HOME/.codex/config.toml"
fi
