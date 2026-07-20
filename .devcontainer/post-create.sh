#!/usr/bin/env bash
set -euo pipefail

# .venv and the uv cache are named volumes that mask the host bind mount
# (platform-specific binaries must not be shared between host and container).
# Named volumes are created root-owned on first use, so fix ownership first
# (a no-op on subsequent creates). ~/.cache itself is included: docker creates
# missing mountpoint parents as root, and tools like prek need ~/.cache/<name>.
sudo chown vscode:vscode /workspace/.venv "$HOME/.cache" "$HOME/.cache/uv"

uv sync --frozen

# Install prek (pre-commit hook runner) and register the git pre-commit hook.
# uv tool install is idempotent; invoke via the tool bin dir (~/.local/bin on
# Linux) in case it is not on PATH yet in this shell.
uv tool install prek
"$HOME/.local/bin/prek" install

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
