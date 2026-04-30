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

## Host integration

*   **Claude authentication:** The container authenticates via the `CLAUDE_CODE_OAUTH_TOKEN` environment variable (Max subscription). Host `~/.claude` is also bind-mounted for sharing projects/sessions state. If `~/.claude` does not exist yet, create it first: `mkdir -p ~/.claude`.
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
