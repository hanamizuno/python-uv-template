#!/usr/bin/env bash
# Runs on the HOST before container create/start (initializeCommand).
# Stages the host's global gitignore so post-start.sh can seed it into the
# container. Must never block container startup: every path exits 0.
set -u

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

exit 0
