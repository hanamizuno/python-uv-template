#!/usr/bin/env bash
# Runs on the HOST before container create/start (initializeCommand).
# Stages host config (global gitignore, Claude Code settings/statusline) so
# post-start.sh can seed it into the container. Must never block container
# startup: every path exits 0.
set -u

# --- compose.local.yaml stub --------------------------------------------------
# compose.local.yaml is listed in devcontainer.json's dockerComposeFile as the
# git-ignored local override; docker compose fails to start when it is missing,
# so generate a no-op stub.
COMPOSE_LOCAL=".devcontainer/compose.local.yaml"
[ -f "$COMPOSE_LOCAL" ] || printf 'services:\n  app: {}\n' > "$COMPOSE_LOCAL"

STAGE=".devcontainer/host-gitignore"

resolve() {
  local p
  p="$(git config --global --get core.excludesFile 2>/dev/null)"
  case "$p" in "~/"*) p="$HOME/${p#\~/}" ;; esac
  [ -n "$p" ] && [ -f "$p" ] && { printf '%s\n' "$p"; return; }
  p="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
  [ -f "$p" ] && { printf '%s\n' "$p"; return; }
  [ -f "$HOME/.gitignore" ] && printf '%s\n' "$HOME/.gitignore"
}

SRC="$(resolve)"

# Remove the previous stage first: cp -L preserves source permissions, so a
# read-only source (e.g. Nix store) would leave a stage that cp cannot overwrite.
rm -f "$STAGE"

if [ -n "${SRC:-}" ]; then
  # -L dereferences symlinks (e.g. Nix-store/home-manager targets).
  cp -L "$SRC" "$STAGE" 2>/dev/null && chmod 644 "$STAGE" 2>/dev/null || rm -f "$STAGE"
fi

# --- Claude Code settings + statusline --------------------------------------
# Auth/state (~/.claude.json, ~/.claude/.credentials.json) is intentionally NOT
# staged; it stays in the container-scoped volume (see README).
CLAUDE_STAGE=".devcontainer/host-claude"
CONTAINER_HOME="/home/vscode"

rm -rf "$CLAUDE_STAGE"

if [ -f "$HOME/.claude/settings.json" ] || [ -f "$HOME/.claude/statusline-command.sh" ]; then
  mkdir -p "$CLAUDE_STAGE"
  if [ -f "$HOME/.claude/settings.json" ]; then
    # Rewrite host-home paths (e.g. the statusLine command) to the container home.
    sed "s|$HOME|$CONTAINER_HOME|g" "$HOME/.claude/settings.json" \
      >"$CLAUDE_STAGE/settings.json" 2>/dev/null || rm -f "$CLAUDE_STAGE/settings.json"
  fi
  if [ -f "$HOME/.claude/statusline-command.sh" ]; then
    cp -L "$HOME/.claude/statusline-command.sh" "$CLAUDE_STAGE/statusline-command.sh" 2>/dev/null \
      && chmod 755 "$CLAUDE_STAGE/statusline-command.sh" 2>/dev/null \
      || rm -f "$CLAUDE_STAGE/statusline-command.sh"
  fi
fi

# --- Git identity (user.name / user.email) -----------------------------------
# Read values (not the file) so includes/conditional includes resolve, and only
# the identity is inherited — not credential helpers etc. that are host-only.
GITUSER_STAGE=".devcontainer/host-gituser"

rm -f "$GITUSER_STAGE"

GIT_NAME="$(git config --global --get user.name 2>/dev/null)"
GIT_EMAIL="$(git config --global --get user.email 2>/dev/null)"
if [ -n "$GIT_NAME" ]; then
  git config --file "$GITUSER_STAGE" user.name "$GIT_NAME" 2>/dev/null || rm -f "$GITUSER_STAGE"
fi
if [ -n "$GIT_EMAIL" ]; then
  git config --file "$GITUSER_STAGE" user.email "$GIT_EMAIL" 2>/dev/null || rm -f "$GITUSER_STAGE"
fi

# --- Proton Pass PAT (task secrets) ------------------------------------------
# Stage the Proton Pass personal access token from the macOS Keychain (same
# git-ignored host-* staging idiom as above) so post-start.sh can log pass-cli
# in inside the container; post-start.sh deletes the stage right after login.
# No Keychain item — or no `security` at all (Linux/Windows) — means nothing is
# staged and the container works normally, just without pass-cli secrets.
# See README "Task secrets via Proton Pass (pass-cli)".
# Keychain lookup is per-project first (proton-pass-agent-pat-<dir name>), then
# the shared default (proton-pass-agent-pat). Registering a project-specific
# item opts this project into its own vault-scoped PAT — no config needed here.
PAT_STAGE=".devcontainer/host-proton-pat"
rm -f "$PAT_STAGE"
if command -v security >/dev/null 2>&1; then
  umask 077
  PROJECT_SERVICE="proton-pass-agent-pat-$(basename "$PWD")"
  security find-generic-password -w -s "$PROJECT_SERVICE" >"$PAT_STAGE" 2>/dev/null ||
    security find-generic-password -w -s proton-pass-agent-pat >"$PAT_STAGE" 2>/dev/null || {
      rm -f "$PAT_STAGE"
      echo "initialize.sh: neither $PROJECT_SERVICE nor proton-pass-agent-pat found in Keychain; pass-cli login will be skipped" >&2
    }
fi

exit 0
