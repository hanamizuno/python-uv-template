#!/usr/bin/env bash
# Runs on the HOST, from the repository root, before `sbx create`. Opt-in:
# skip it (or run with --remove) and the sandbox gets no host Claude Code
# settings.
#
# Stages the host's Claude Code settings + statusline into the kit's static
# files (files/home/ -> /home/agent/), which sbx copies into the VM at creation.
# The VM's own ~/.claude/settings.json is sandbox-managed (kit reference:
# "Sandbox-managed agent configuration"), so the host settings land in a
# separate file that Claude Code loads with --settings:
#   sbx exec -it -w "$PWD" claude-<dir> claude --permission-mode auto \
#     --settings /home/agent/.claude/host-settings.json
# Auth/state (~/.claude.json, credentials) is intentionally NOT staged.
# Static files are read only at creation: re-run this and recreate the sandbox
# to pick up host changes.
set -eu

STAGE=".sandbox/kit/files/home/.claude"
VM_HOME="/home/agent"

if [ ! -d .sandbox/kit ]; then
  echo "run from the repository root" >&2
  exit 1
fi

rm -f "$STAGE/host-settings.json" "$STAGE/statusline-command.sh"

if [ "${1:-}" = "--remove" ]; then
  echo "removed the staged host Claude Code settings"
  exit 0
fi

mkdir -p "$STAGE"

if [ -f "$HOME/.claude/settings.json" ]; then
  # Rewrite host-home paths (e.g. the statusLine command) to the VM home.
  sed "s|$HOME|$VM_HOME|g" "$HOME/.claude/settings.json" >"$STAGE/host-settings.json"
  echo "staged $STAGE/host-settings.json"
fi

if [ -f "$HOME/.claude/statusline-command.sh" ]; then
  # -L dereferences symlinks (e.g. Nix-store/home-manager targets).
  cp -L "$HOME/.claude/statusline-command.sh" "$STAGE/statusline-command.sh"
  chmod 755 "$STAGE/statusline-command.sh"
  echo "staged $STAGE/statusline-command.sh"
fi
