# AI Agent Dev Container

The Dev Container is also the runtime for AI coding agents (Claude Code, Codex, etc.). The agent toolchain is layered on top of the Python environment via [Dev Container Features](https://containers.dev/implementors/features/) and post-create setup, so no per-project agent compose override is needed.

## Included Features

| Feature | Source |
|---|---|
| Common utilities (non-root `vscode` user, sudo, packages) | `ghcr.io/devcontainers/features/common-utils:2` |
| GitHub CLI | `ghcr.io/devcontainers/features/github-cli:1` |
| Node.js (required by `claude-code`) | `ghcr.io/devcontainers/features/node:1` |
| Claude Code CLI | `ghcr.io/anthropics/devcontainer-features/claude-code:1` |
| Codex CLI | Installed by `./post-create.sh` with `npm install -g @openai/codex` |
| Codex plugin for Claude Code | Installed by `./post-create.sh` with `claude plugin install codex@openai-codex`, so Claude Code can delegate to Codex on demand (the `codex-rescue` subagent + `/codex` skills) |

To add another agent CLI (e.g. Cursor), drop in either an upstream Feature, a local `./<feature-id>/` directory referenced from `features`, or an idempotent install step in `./post-create.sh`.

## Initial setup

1. **Open the container** — VS Code "Reopen in Container", or headless: `devcontainer up --workspace-folder .`
2. **Authenticate** (one-time per devcontainer ID; persisted in named volumes, not bind-mounted from the host):
   - **Claude Code**: just start the agent — on first launch it shows the login flow inline. Do NOT pass `/login` as a CLI argument; that is a slash command for an active session and triggers the flow twice when used from the host shell.
     ```bash
     devcontainer exec --workspace-folder . claude --dangerously-skip-permissions
     ```
   - **Codex CLI**: start the agent and sign in with ChatGPT, or configure `OPENAI_API_KEY` inside the container. The first container creation copies `./codex-config.toml` into the persisted `~/.codex/config.toml` volume. The same post-create step also installs the `codex@openai-codex` plugin into Claude Code's `~/.claude` volume, so Claude Code can call Codex on demand (the `codex-rescue` subagent + `/codex` skills) without re-installing the plugin per session.
     ```bash
     devcontainer exec --workspace-folder . codex
     ```
   - **GitHub CLI** — pick one of the following:
     - **Web flow** (interactive, OAuth scopes selected at login):
       ```bash
       devcontainer exec --workspace-folder . gh auth login --hostname github.com --git-protocol https --web
       ```
     - **Seed from a host token** (e.g. `$GH_TOKEN` from `gh auth token`):
       ```bash
       devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT=$GH_TOKEN \
         sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
       ```
     - **Scoped PAT** (recommended for autonomous runs) — see [Restricting GitHub permissions](#restricting-github-permissions-pat) below.
   Credentials live in `claude-config-${devcontainerId}`, `codex-config-${devcontainerId}`, and `gh-config-${devcontainerId}` volumes and survive `--remove-existing-container` rebuilds.

## Host config inheritance

On every container create/start, `./initialize.sh` (an `initializeCommand`, runs on the host) stages selected host config into git-ignored files under `./`, and `./post-start.sh` seeds them inside the container:

- **Global gitignore** — resolved via `core.excludesFile` → `~/.config/git/ignore` (XDG) → `~/.gitignore`, dereferencing symlinks (e.g. Nix/home-manager targets); staged as `./host-gitignore` and copied to `~/.config/git/ignore` (git's XDG default, so no `git config` is touched). Overwritten on every start — the host is the source of truth.
- **Git identity** — `user.name` / `user.email` are read from the host's global git config (values, not the file, so includes resolve and host-only settings like credential helpers are not carried over), staged as `./host-gituser`, and applied in the container via `git config --global` on every start. Keys unset on the host are left alone.
- **Claude Code settings + statusline** — `~/.claude/settings.json` is staged with host-home paths rewritten to `/home/vscode` (so e.g. the `statusLine` command keeps working) and **deep-merged** into the container's `~/.claude/settings.json` with `jq` (host wins per key; container-only keys such as in-container plugin enables survive). `~/.claude/statusline-command.sh` is copied alongside. Auth/state (`~/.claude.json`, `~/.claude/.credentials.json`) is intentionally **not** staged — authentication stays in the container-scoped volume.

If a host file does not exist its step is a no-op and the container starts normally.

> **Windows hosts:** `initializeCommand` runs a bash script on the host, so native Windows needs Git Bash/WSL on `PATH` — otherwise the sync is skipped but the container still starts.

## Operating modes

- **Default (egress open)** — outbound traffic is unrestricted. Host credentials are *not* bind-mounted (Claude/Codex/`gh` auth lives in container-scoped volumes), and the host Docker socket is not exposed. The defense surface for autonomous agent runs is: non-root `vscode` user, workspace-only mount, container-scoped auth volumes. Codex is seeded with `approval_policy = "never"` and `sandbox_mode = "workspace-write"` in its container-scoped config, which lets it work without pauses while keeping writes scoped to the workspace.
- **Isolated mode (optional)** — for a stricter sandbox, create a Docker network with no egress and attach the container to it:
  ```bash
  docker network create --internal agent-internal
  ```
  Then add `"runArgs": ["--network=agent-internal"]` to a local override (e.g. `./devcontainer.local.json` or a separate workspace). Outbound is fully blocked, so resolve dependencies (`uv sync`, etc.) before switching, and run a proxy sidecar if the agent still needs API access.

## What this isolation *does not* cover

The container compresses the blast radius from "everything the host user can touch" down to "the workspace + container-scoped auth volumes" — but it is still a Linux container, not a microVM. Specifically, this template does **not** provide:

- A separate kernel (a container-escape kernel exploit is not contained).
- Granular network allow/deny lists (only the binary `--network=internal` mode above; the previous iptables-based allowlist was removed because it was hard to keep correct).
- A nested Docker daemon for safely building/running containers from inside the agent session (the host Docker socket is intentionally not mounted).

If you need any of those, run the agent inside a higher-assurance sandbox such as [Docker Sandbox](https://docs.docker.com/ai/sandboxes/) (microVM kernel boundary, allow/deny networking, per-sandbox Docker daemon) and treat this devcontainer as the inner workspace.

**Host loopback access is intentionally not opened.** `host.docker.internal` is not added by default — opening it would expose every `0.0.0.0`-bound host service (local LLM servers, dev DBs, debug dashboards) to the agent. If you specifically need it — e.g. to point an agent at a locally hosted OpenAI-compatible endpoint — add it as a local override, not a project default:

```jsonc
// .devcontainer/devcontainer.local.json (per-user override; do not commit)
{ "runArgs": ["--add-host=host.docker.internal:host-gateway"] }
```

Then bind the host service to `0.0.0.0` (not `127.0.0.1`) so the bridge network can reach it, and configure the agent to use `http://host.docker.internal:<port>`.

## Restricting GitHub permissions (PAT)

When Claude Code runs with `--dangerously-skip-permissions`, it inherits whatever scopes the stored `gh` token has. To limit blast radius, seed the volume with a dedicated PAT instead of your everyday `$GH_TOKEN`.

**Steps:**

1. Issue a PAT in GitHub:
   - **Fine-grained** (preferred for narrow blast radius) — pick the target repo(s) and the minimum permissions from the table below.
   - **Classic** with the smallest scope set that covers your needs (e.g. `repo` only) — use this if a `gh` operation you rely on is not yet supported by fine-grained PATs.
2. Replace any existing auth so scopes don't accumulate:
   ```bash
   devcontainer exec --workspace-folder . gh auth logout --hostname github.com
   ```
3. Seed the volume with the new PAT (avoid leaving the value in shell history — leading-space the line, or read from a file):
   ```bash
    GH_PAT='github_pat_xxx' devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT=$GH_PAT \
      sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
   unset GH_PAT
   ```
   Or, from a token file:
   ```bash
   devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT="$(cat ~/.config/agent-gh-pat)" \
     sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
   ```
4. Verify the granted scopes:
   ```bash
   devcontainer exec --workspace-folder . gh auth status
   devcontainer exec --workspace-folder . sh -c '
     gh auth token | xargs -I{} curl -sI -H "Authorization: token {}" https://api.github.com/user \
       | grep -iE "x-oauth-scopes|x-accepted"
   '
   ```
   Classic PATs show granted scopes via `x-oauth-scopes`. Fine-grained PATs show empty there — read the resource permissions on the PAT settings page directly.

**Suggested minimum permissions (fine-grained):**

| Operation Claude should perform | Permission |
|---|---|
| Read issues / PRs / repo metadata | `Issues: Read`, `Pull requests: Read`, `Metadata: Read` |
| Comment on / open / close PRs | `+ Pull requests: Write`, `Issues: Write` |
| HTTPS `git push` / commit | `+ Contents: Write` (repo-scoped) |
| GitHub Actions read/dispatch | `+ Actions: Read` (or `Write` if dispatch needed) |
| Repository creation / settings | `+ Administration: Write` (org may require approval) |

**Notes / gotchas:**

- Fine-grained PATs do not yet cover every `gh` subcommand — if you hit a 403 or "PAT not supported" error, fall back to a tightly-scoped classic PAT.
- The token sits in `~/.config/gh/hosts.yml` inside the volume. Anyone with shell access in the container can read it, so treat compromise of the container as compromise of the token's scope.
- Rotate by repeating step 2 + 3 — you do not need to recreate the volume.

## Notes

- Pulling Feature updates: `devcontainer up --workspace-folder . --remove-existing-container` (or VS Code → "Rebuild Container").
- Host Docker socket is intentionally not mounted; the agent cannot manipulate host containers.
