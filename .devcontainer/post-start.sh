#!/usr/bin/env bash
set -euo pipefail

test -d .venv || uv sync --frozen

# Seed the host's global gitignore (staged by initialize.sh) into git's XDG
# default path. ~/.config/git is not a named volume, so overwriting keeps the
# host as the source of truth on every start.
if [ -f .devcontainer/host-gitignore ]; then
  mkdir -p "$HOME/.config/git"
  rm -f "$HOME/.config/git/ignore"
  cp .devcontainer/host-gitignore "$HOME/.config/git/ignore"
fi

# Seed Claude Code config staged by initialize.sh. settings.json is deep-merged
# (host wins per key) instead of overwritten because Claude Code itself writes
# to it inside the container — container-only keys (plugin enables, /config
# changes) survive unless the host defines the same key. Auth is never staged.
if [ -f .devcontainer/host-claude/statusline-command.sh ]; then
  mkdir -p "$HOME/.claude"
  rm -f "$HOME/.claude/statusline-command.sh"
  cp .devcontainer/host-claude/statusline-command.sh "$HOME/.claude/statusline-command.sh"
fi

if [ -f .devcontainer/host-claude/settings.json ]; then
  mkdir -p "$HOME/.claude"
  target="$HOME/.claude/settings.json"
  if command -v jq >/dev/null 2>&1 && [ -f "$target" ] &&
    jq -s '.[0] * .[1]' "$target" .devcontainer/host-claude/settings.json >"$target.tmp" 2>/dev/null; then
    mv "$target.tmp" "$target"
  else
    # No jq or no/invalid existing settings: fall back to a plain copy.
    rm -f "$target.tmp" "$target"
    cp .devcontainer/host-claude/settings.json "$target"
  fi
fi
