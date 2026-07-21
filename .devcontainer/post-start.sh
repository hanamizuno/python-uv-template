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

# Seed the host's git identity (staged by initialize.sh). Applied via
# `git config --global` so container-side git config (e.g. safe.directory
# written by features) is left untouched. Overwritten on every start — the
# host is the source of truth.
if [ -f .devcontainer/host-gituser ]; then
  name="$(git config --file .devcontainer/host-gituser --get user.name 2>/dev/null || true)"
  email="$(git config --file .devcontainer/host-gituser --get user.email 2>/dev/null || true)"
  if [ -n "$name" ]; then git config --global user.name "$name"; fi
  if [ -n "$email" ]; then git config --global user.email "$email"; fi
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

# --- Proton Pass (pass-cli): task secrets ------------------------------------
# Persist the PAT staged by initialize.sh as .devcontainer/host-proton-pat into
# the container (0600, outside the workspace mount) so agents can log pass-cli
# in — and re-login after session expiry — via .devcontainer/pass-relogin.
# No login happens here; sessions are established on demand by the agent.
# The stage is deleted right after — it is a regular file inside the workspace
# mount, so the delete propagates to the host copy too. Deletion runs from an
# EXIT trap so any failure (set -e) cannot leave the PAT behind. A missing
# stage does NOT remove an existing container copy: initializeCommand may have
# been skipped (e.g. Windows host without bash), and losing the copy would
# take re-login down with it.
trap 'rm -f .devcontainer/host-proton-pat' EXIT
if command -v pass-cli >/dev/null 2>&1; then
  export PROTON_PASS_SESSION_DIR="${PROTON_PASS_SESSION_DIR:-$HOME/.local/state/proton-pass}"
  # Fix ownership of the session-volume mountpoint and its parents: docker
  # creates missing mountpoint paths as root (also repairs volumes created
  # before the Dockerfile pre-created these directories).
  sudo mkdir -p "$PROTON_PASS_SESSION_DIR"
  sudo chown vscode:vscode "$HOME/.local" "$HOME/.local/state" "$PROTON_PASS_SESSION_DIR"
  # Kept in ~/.local/state/proton-pass-agent (NOT the pass-cli session dir,
  # which pass-cli manages and `logout` may clear). Plain container FS, no
  # volume: initialize.sh re-stages on every `devcontainer up`, so recreation
  # repopulates it.
  if [ -s .devcontainer/host-proton-pat ]; then
    install -d -m 700 "$HOME/.local/state/proton-pass-agent"
    install -m 600 .devcontainer/host-proton-pat "$HOME/.local/state/proton-pass-agent/pat"
  fi
fi
