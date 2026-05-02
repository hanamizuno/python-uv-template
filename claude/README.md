# Claude Code Container

An isolated container for running Claude Code autonomously with `--dangerously-skip-permissions`. The container provides:

*   **Network firewall:** iptables-based outbound traffic control
*   **Non-root user:** Runs as `claude` (UID 1000)
*   **No Docker socket:** Cannot access host Docker
*   **Workspace isolation:** Only the project directory is mounted

This directory contains:

*   `Dockerfile` — image definition (firewall tooling + non-root `claude` user)
*   `entrypoint.sh` — applies the firewall mode then drops to the `claude` user
*   `init-firewall.sh` — iptables/ipset rules for `strict` and `open` modes

## Firewall Modes

| Mode | Description | Use case |
|---|---|---|
| `strict` (default) | Allowlist only (GitHub, PyPI, Anthropic API, GCS) | Implementation, testing, refactoring |
| `open` | All outbound HTTPS/HTTP allowed | Tasks requiring web search |

### Firewall caveats

The firewall provides best-effort outbound restriction, not airtight isolation. Be aware of the following:

*   **IPv6 is not filtered.** `init-firewall.sh` only configures `iptables` (IPv4). On dual-stack hosts where the container has IPv6 connectivity, IPv6 traffic bypasses the allowlist entirely. If IPv6 is reachable in your environment, disable it on the container network or extend the script to call `ip6tables -P OUTPUT DROP`.
*   **The host LAN is fully reachable.** The script allows the entire `/24` of the container's default gateway so that Docker host services work. On home/office networks this means routers, NAS, printers, and other LAN devices are reachable from the container. Treat the container as if it can talk to your local network.
*   **DNS-resolved IPs are pinned at startup.** Domains like `pypi.org`, `api.anthropic.com`, and `storage.googleapis.com` are resolved once when the container starts and the resulting IPs are added to the allowlist. CDN-backed services may rotate IPs over hours/days, after which connections silently fail until you restart the container.
*   **Strict mode is not zero-trust.** Anything reachable via the GitHub/PyPI/Anthropic/GCS IP ranges is reachable. A malicious package on PyPI, for example, can still be installed.

## Host integration

*   **Claude authentication:** The container authenticates via the `CLAUDE_CODE_OAUTH_TOKEN` environment variable (Max subscription). Host `~/.claude` is also bind-mounted **read-write** for sharing projects/sessions state. If `~/.claude` does not exist yet, create it first: `mkdir -p ~/.claude`.

    > **⚠️ Risk:** The bind mount is read-write, so anything running inside the container — including a misbehaving Claude Code session or any process the agent spawns — can modify or delete files under host `~/.claude` (settings, project history, session logs). Keep this in mind when running with `--dangerously-skip-permissions`. If you need stronger isolation, mount only the specific subpath you require, or back up `~/.claude` before long autonomous sessions.
*   **GitHub CLI authentication:** The container receives `GH_TOKEN` so `gh` commands work without interactive login. macOS Keychain-stored tokens are not accessible from Linux containers, so `GH_TOKEN` is required.
*   **Git author info:** The startup script (`scripts/claude-start.sh`) automatically reads `user.name` / `user.email` from your host's `git config` and passes them as environment variables. Works with any git config layout (standard, XDG, Nix/home-manager).
*   **SSH & GitHub CLI credentials (opt-in):** Adding the override file `compose.claude.auth.yml` mounts `~/.ssh` and `~/.config/gh` read-only. Required for `git push`/`pull` via SSH and `gh` CLI operations (PR creation, issue management, etc.).

## Initial setup (authentication tokens)

Both Claude Code and GitHub CLI store tokens in macOS Keychain, which is not accessible from Linux containers or mosh/ssh sessions. Export the tokens as environment variables instead.

1.  **Claude Code token** (Max subscription, valid for 1 year):
    ```bash
    claude setup-token
    # Add to ~/.config/claude-code/env:
    export CLAUDE_CODE_OAUTH_TOKEN=<token>
    ```
    > **Note:** `ANTHROPIC_API_KEY` is for pay-per-use API billing, not Max subscription. Do not use it here.

2.  **GitHub CLI token:**
    ```bash
    gh auth token
    # Add to ~/.config/claude-code/env:
    export GH_TOKEN=<token>
    ```

3.  **Apply to current shell:**
    ```bash
    source ~/.config/claude-code/env
    ```
    Or open a new terminal. `scripts/claude-start.sh` passes these environment variables into the container automatically.

## Usage

All commands below are run from the repository root.

```bash
# Start (strict firewall)
scripts/claude-start.sh up -d

# Start (HTTPS open)
FIREWALL_MODE=open scripts/claude-start.sh up -d

# Start with host SSH & GitHub CLI credentials mounted
scripts/claude-start.sh -f compose.claude.auth.yml up -d

# Run Claude Code
docker compose -f compose.claude.yml exec claude claude --dangerously-skip-permissions

# Stop
docker compose -f compose.claude.yml down
```
