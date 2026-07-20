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
# Log pass-cli in from the PAT staged by initialize.sh as .devcontainer/
# host-proton-pat (no stage = no PAT on this host; skip silently). The session
# lives in a named volume, so the login runs only on first start and after a
# PAT rotation. The stage is deleted right after — it is a regular file inside
# the workspace mount, so the delete propagates to the host copy too.
if command -v pass-cli >/dev/null 2>&1; then
  export PROTON_PASS_KEY_PROVIDER="${PROTON_PASS_KEY_PROVIDER:-fs}"
  export PROTON_PASS_SESSION_DIR="${PROTON_PASS_SESSION_DIR:-$HOME/.local/state/proton-pass}"
  # Fix ownership of the session-volume mountpoint and its parents: docker
  # creates missing mountpoint paths as root (also repairs volumes created
  # before the Dockerfile pre-created these directories).
  sudo mkdir -p "$PROTON_PASS_SESSION_DIR"
  sudo chown vscode:vscode "$HOME/.local" "$HOME/.local/state" "$PROTON_PASS_SESSION_DIR"
  # A set PROTON_PASS_PERSONAL_ACCESS_TOKEN makes `pass-cli login` take the PAT
  # flow (safer than passing the token in argv via --pat). A stale local session
  # (e.g. expired server-side) makes `login` fail with "Already authenticated",
  # so clear it first — logout is a no-op when there is no session.
  if ! pass-cli vault list >/dev/null 2>&1 && [ -s .devcontainer/host-proton-pat ]; then
    pass-cli logout >/dev/null 2>&1 || true
    PROTON_PASS_PERSONAL_ACCESS_TOKEN="$(cat .devcontainer/host-proton-pat)" \
      pass-cli login
  fi

  # Seed gh auth on first start from the item `github-fine-grained` in whatever
  # vault(s) this PAT can see — per-project vaults keep their own repo-scoped
  # GitHub PAT under that fixed item name. Best-effort: skipped when no such
  # item exists or gh is already authenticated.
  # PROTON_PASS_AGENT_REASON is required for item access on PAT (agent)
  # sessions — without it `pass-cli run` fails (and the failure is swallowed
  # here). The value is recorded in Proton's audit log.
  if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
    pass-cli vault list 2>/dev/null | sed -n 's/^- \[[^]]*\]: //p' |
      while IFS= read -r vault; do
        PROTON_PASS_AGENT_REASON="Seed gh auth from github-fine-grained (devcontainer post-start)" \
          GH_SEED_TOKEN="pass://$vault/github-fine-grained/token" \
          pass-cli run -- sh -c 'printf %s "$GH_SEED_TOKEN" | gh auth login --with-token' \
          >/dev/null 2>&1 || true
        gh auth status >/dev/null 2>&1 && break
      done || true
  fi
fi
rm -f .devcontainer/host-proton-pat
