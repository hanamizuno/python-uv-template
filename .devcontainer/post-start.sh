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
