#!/usr/bin/env bash
set -euo pipefail

uv sync --frozen

# No sudo: npm is nvm-managed (not on sudo's secure_path) and the nvm tree is
# vscode-writable, so a plain global install works.
if ! command -v codex >/dev/null 2>&1; then
  npm install -g @openai/codex
fi

mkdir -p "$HOME/.codex"

if [ ! -f "$HOME/.codex/config.toml" ]; then
  cp .devcontainer/codex-config.toml "$HOME/.codex/config.toml"
fi

# Register Codex as a Claude Code plugin so Claude Code can delegate to Codex on
# demand (the codex-rescue subagent + /codex skills). The ~/.claude volume persists
# across rebuilds, so guard on "already installed" to stay idempotent.
if ! claude plugin list 2>/dev/null | grep -q 'codex@openai-codex'; then
  claude plugin marketplace add openai/codex-plugin-cc || true
  claude plugin install codex@openai-codex
fi

if ! command -v hermes >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
fi

mkdir -p "$HOME/.hermes"

if [ ! -f "$HOME/.hermes/config.yaml" ]; then
  cp .devcontainer/hermes-config.yaml "$HOME/.hermes/config.yaml"
fi
