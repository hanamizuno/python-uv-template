#!/usr/bin/env bash
# Runs on the HOST. Opt-in: copies the host's Claude Code settings + statusline
# into a sandbox. Normally invoked by the postCreate command of the
# host-claude overlay, which supplies SBX_SANDBOX_NAME:
#   sbx env run ./.sandbox/claude-auto ./.sandbox/host-claude
# It can also be run by hand against an existing, running sandbox:
#   ./.sandbox/stage-host-claude.sh <sandbox name>
#
# The VM's own ~/.claude/settings.json is sandbox-managed (the built-in kit
# writes it), so the host settings land in a separate file that Claude Code
# loads with --settings (the overlay's cmd adds it). Auth/state
# (~/.claude.json, credentials) is intentionally NOT copied.
set -eu

SANDBOX="${1:-${SBX_SANDBOX_NAME:-}}"
VM_HOME="/home/agent"

if [ -z "$SANDBOX" ]; then
  echo "usage: $0 <sandbox name>" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -f "$HOME/.claude/settings.json" ]; then
  # Rewrite host-home paths (e.g. the statusLine command) to the VM home.
  sed "s|$HOME|$VM_HOME|g" "$HOME/.claude/settings.json" >"$TMP/host-settings.json"
  sbx cp "$TMP/host-settings.json" "$SANDBOX:$VM_HOME/.claude/host-settings.json"
  echo "copied host-settings.json into $SANDBOX"
fi

if [ -f "$HOME/.claude/statusline-command.sh" ]; then
  # -L dereferences symlinks (e.g. Nix-store/home-manager targets).
  cp -L "$HOME/.claude/statusline-command.sh" "$TMP/statusline-command.sh"
  chmod 755 "$TMP/statusline-command.sh"
  sbx cp "$TMP/statusline-command.sh" "$SANDBOX:$VM_HOME/.claude/statusline-command.sh"
  echo "copied statusline-command.sh into $SANDBOX"
fi
