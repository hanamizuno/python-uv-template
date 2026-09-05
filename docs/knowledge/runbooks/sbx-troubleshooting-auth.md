---
type: Runbook
title: sbx — troubleshooting authentication
description: Recovering from sbx login / sandboxd auth failures, including SSH/headless keychain limitations
tags: [sbx, agents]
timestamp: 2026-09-05T00:00:00Z
---

# sbx — troubleshooting authentication

`sbx` has no dedicated equivalent of `gh auth status`. In practice **`sbx ls` is the auth probe** — if auth is alive you get the sandbox list (cleanly, even when empty); if it's broken, the auth error surfaces directly. Also check `sbx --help` for newly added `account`/`logout` subcommands.

## "cannot prompt for password" / "store is locked" / "secret not found"

These can mean the background `sandboxd` daemon is holding the auth store's lock, or corrupted auth metadata. Recovery (macOS):

```bash
# 1) Stop sandboxd
pkill sandboxd   # or kill the PID in sandboxd.pid under ~/.docker/caches/com.docker.sandboxes/

# 2) Remove the lock files
rm -f ~/.docker/caches/com.docker.sandboxes/sandboxes/.posixage.lock
rm -f ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/.posixage.lock

# 3) Clear the auth metadata (auth side only, not the sandboxes themselves)
rm -rf ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/ZG9ja2VyL2F1dGgvbWV0YWRhdGEvaHViL2RlZmF1bHQ=/

# 4) Restart the daemon and trigger re-authentication
sbx ls
sbx login
```

Be careful not to delete the sandbox data itself (the `com.docker.sandboxes` side, not `-auth`).

## SSH / headless sessions

sbx stores credentials in the OS keychain (Keychain on macOS, Secret Service/D-Bus on Linux). Over SSH or headless, the keychain stays locked and no prompt can be shown, so `sbx login` fails with "saving credentials: cannot prompt the user for password" (same family as [docker/sbx-releases#180](https://github.com/docker/sbx-releases/issues/180) / [#186](https://github.com/docker/sbx-releases/issues/186)).

- **SSH'd into macOS** — unlock the keychain in the same shell first: `security unlock-keychain ~/Library/Keychains/login.keychain-db`. If that still fails, run `sbx login` once from a local GUI session (physical machine or screen-shared terminal).
- **Headless Linux** — start a session D-Bus plus `gnome-keyring-daemon --components=secrets`, and make sure `DBUS_SESSION_BUS_ADDRESS` is inherited by both `sbx` and the daemon (see #186).
- sbx changes its auth handling frequently — update first (`brew upgrade sbx` or equivalent) before digging further.
