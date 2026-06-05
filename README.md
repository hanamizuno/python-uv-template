# Python + uv + AI Agent Development Template

This repository serves as a template for developing Python applications using the [uv](https://docs.astral.sh/uv/) package manager. It comes pre-configured with Docker, Dev Containers, GitHub Actions CI, and common development tools.

## Scope

This template targets **non-distributed Python applications** (services, internal tools, scripts) — it is not intended for building distributable libraries or wheels. It provides only the **outer scaffolding** (CI, containers, security tooling); the inner application code is intentionally minimal.

`myapp/` is a placeholder package — rename it and replace its contents with your own. Tests are co-located under each package's `tests/` directory.

## Features

*   **Modern Python Stack:** Uses Python 3.14+ and `uv` for fast dependency management.
*   **Containerized Development:**
    *   **Docker & Docker Compose:** Provides consistent development and production environments using multi-stage builds (`dev`, `prod`, `devcontainer`).
    *   **VSCode Dev Containers:** Includes a `.devcontainer/devcontainer.json` configuration that layers the AI agent toolchain (Claude Code CLI, Codex CLI, Hermes Agent, GitHub CLI, common utilities) on top of the project's Python environment via [Dev Container Features](https://containers.dev/implementors/features/) and post-create setup.
*   **Development Tools:** Integrated with standard development tools:
    *   [`ruff`](https://docs.astral.sh/ruff/) for linting and formatting.
    *   [`pyright`](https://microsoft.github.io/pyright/) for static type checking.
    *   [`pytest`](https://docs.pytest.org/) for testing (including coverage reports).
    *   [`taskipy`](https://github.com/taskipy/taskipy) for managing project tasks.
*   **CI/CD:** Includes GitHub Actions workflows (`.github/workflows/`) for automated linting and testing on code pushes.

## Security

This project implements supply chain attack protections.
cf. https://zenn.dev/dajiaji/articles/47164ff27d2123

- **Lockfile Integrity**: CI uses `uv sync --frozen` to detect lockfile tampering
- **Minimum Privileges**: Workflows use `permissions: {}` at top level
- **SHA Pinning**: All GitHub Actions are pinned to commit SHAs
- **Dependabot Cooldown**: 7-day delay before accepting new package versions
- **Vulnerability Scanning**: Trivy scans dependencies on every PR (results in GitHub Security tab)
- **SBOM Generation**: CycloneDX SBOM generated on dependency changes
- **Workflow Auditing**: zizmor checks for workflow security issues

## Directory Structure

```
.
├── .claude/                    # Claude Code shared settings (committed)
├── .devcontainer/              # Dev Container config (also runs the AI agent toolchain via Features)
│   ├── codex-config.toml        # Initial Codex CLI config copied into the persisted ~/.codex volume
│   ├── hermes-config.yaml       # Initial Hermes Agent config copied into the persisted ~/.hermes volume
│   ├── devcontainer.json
│   └── post-create.sh
├── .dockerignore
├── .editorconfig
├── .github/                    # GitHub-specific files
│   ├── dependabot.yml          # Dependabot configuration
│   ├── ISSUE_TEMPLATE/
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/              # GitHub Actions CI workflows
│       ├── lint.yml
│       ├── lint_docker.yml
│       ├── lint_gha.yml
│       ├── sbom.yml            # SBOM generation
│       ├── security.yml        # Vulnerability scanning
│       └── test.yml
├── .gitignore
├── .python-version             # Specifies Python version (primarily for uv/tooling)
├── .vscode/                    # VSCode-specific files
│   └── settings.json
├── AGENTS.md                   # Project guidelines for AI agents and humans
├── CLAUDE.md                   # Pointer to AGENTS.md for Claude Code
├── Dockerfile                  # Defines container images (dev, prod, devcontainer)
├── README.md                   # This file
├── compose.dev.yml             # Docker Compose configuration for development
├── compose.yml                 # Docker Compose configuration for production
├── docs/                       # Documentation and AI agent related files
│   └── agents/                 # Stores execution plans for development tasks (e.g., *.md)
├── myapp/                      # Placeholder application package — rename and replace
│   ├── __init__.py
│   ├── main.py                 # Sample application code
│   └── tests/                  # Co-located tests (no __init__.py — uses pytest importlib mode)
│       └── main_test.py
├── pyproject.toml              # Project metadata and tool config (uv, ruff, pyright, pytest, taskipy)
└── uv.lock                     # Pinned versions of dependencies
```

## Getting Started

### Prerequisites

*   Docker and Docker Compose
*   VSCode with the "Dev Containers" extension
*   uv (if not using Docker)

### Setup Options

#### Option 1: Using VSCode Dev Containers

1.  Open this repository in VSCode.
2.  When prompted ("Reopen in Container"), click it. VSCode will build the development container and connect to it automatically.
3.  You can now use the integrated terminal in VSCode, which runs inside the container.

#### Option 2: Using Docker Compose Manually

1.  **Build the development image:**
    ```bash
    docker compose -f compose.dev.yml build
    ```
2.  **Run commands inside the container:**
    ```bash
    docker compose -f compose.dev.yml run --rm app <command>
    ```
    For example, to run tests:
    ```bash
    docker compose -f compose.dev.yml run --rm app task test
    ```
    To get an interactive shell:
    ```bash
    docker compose -f compose.dev.yml run --rm app bash
    ```

#### Option 3: Using uv locally (without Docker)
1.  **Install `uv`** (if not already installed):
    ```bash
    # cf. https://github.com/astral-sh/uv?tab=readme-ov-file#installation
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ```
2.  **Install dependencies:**
    ```bash
    uv sync
    ```
3.  **Run commands:**
    ```bash
    uv run <command>
    ```
    For example, to run tests:
    ```bash
    uv run task test
    ```

### Available Tasks (using Taskipy)

Run these tasks inside the development container (either via Dev Containers terminal or `docker compose run`):

*   `task lint`: Run linters (`ruff check` and `pyright`).
*   `task fix`: Automatically fix linting issues with `ruff`.
*   `task format`: Format code with `ruff format`.
*   `task test`: Run tests with `pytest`.
*   `task test_cov`: Run tests and generate coverage reports.

Example:
```bash
# Inside Dev Container terminal or after `docker compose run ... bash`
task lint
task test_cov
```

## AI Agent Dev Container

The Dev Container is also the runtime for AI coding agents (Claude Code, Codex, etc.). The agent toolchain is layered on top of the Python environment via [Dev Container Features](https://containers.dev/implementors/features/) and post-create setup, so no per-project agent compose override is needed.

### Included Features

| Feature | Source |
|---|---|
| Common utilities (non-root `vscode` user, sudo, packages) | `ghcr.io/devcontainers/features/common-utils:2` |
| GitHub CLI | `ghcr.io/devcontainers/features/github-cli:1` |
| Node.js (required by `claude-code`) | `ghcr.io/devcontainers/features/node:1` |
| Claude Code CLI | `ghcr.io/anthropics/devcontainer-features/claude-code:1` |
| Codex CLI | Installed by `.devcontainer/post-create.sh` with `npm install -g @openai/codex` |
| Codex plugin for Claude Code | Installed by `.devcontainer/post-create.sh` with `claude plugin install codex@openai-codex`, so Claude Code can delegate to Codex on demand (the `codex-rescue` subagent + `/codex` skills) |
| Hermes Agent | Installed by `.devcontainer/post-create.sh` via the upstream `NousResearch/hermes-agent` per-user `uv` installer |

To add another agent CLI (e.g. Cursor), drop in either an upstream Feature, a local `./.devcontainer/<feature-id>/` directory referenced from `features`, or an idempotent install step in `.devcontainer/post-create.sh`.

### Initial setup

1. **Open the container** — VS Code "Reopen in Container", or headless: `devcontainer up --workspace-folder .`
2. **Authenticate** (one-time per devcontainer ID; persisted in named volumes, not bind-mounted from the host):
   - **Claude Code**: just start the agent — on first launch it shows the login flow inline. Do NOT pass `/login` as a CLI argument; that is a slash command for an active session and triggers the flow twice when used from the host shell.
     ```bash
     devcontainer exec --workspace-folder . claude --dangerously-skip-permissions
     ```
   - **Codex CLI**: start the agent and sign in with ChatGPT, or configure `OPENAI_API_KEY` inside the container. The first container creation copies `.devcontainer/codex-config.toml` into the persisted `~/.codex/config.toml` volume. The same post-create step also installs the `codex@openai-codex` plugin into Claude Code's `~/.claude` volume, so Claude Code can call Codex on demand (the `codex-rescue` subagent + `/codex` skills) without re-installing the plugin per session.
     ```bash
     devcontainer exec --workspace-folder . codex
     ```
   - **Hermes Agent**: the installer only drops the binary; pick a provider/model after first launch with `hermes setup` (full wizard) or `hermes model` (provider/model only). Common LLM provider API keys (`OPENROUTER_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `NOUS_PORTAL_API_KEY`) are forwarded from the host shell via `remoteEnv` — set them on the host once and they appear inside the container. The first container creation copies `.devcontainer/hermes-config.yaml` into the persisted `~/.hermes/config.yaml` volume (approvals disabled — the container is the isolation boundary).
     ```bash
     devcontainer exec --workspace-folder . hermes
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
   Credentials live in `claude-config-${devcontainerId}`, `codex-config-${devcontainerId}`, `hermes-config-${devcontainerId}`, and `gh-config-${devcontainerId}` volumes and survive `--remove-existing-container` rebuilds.

### Host gitignore inheritance

The container inherits the host's **global gitignore** so git inside the container hides the same noise (editor files, OS junk) as on the host. On every container create/start, `.devcontainer/initialize.sh` (an `initializeCommand`, runs on the host) resolves the host's global ignore — `core.excludesFile` → `~/.config/git/ignore` (XDG) → `~/.gitignore`, dereferencing symlinks (e.g. Nix/home-manager targets) — and stages it as `.devcontainer/host-gitignore` (git-ignored, never committed). `.devcontainer/post-start.sh` then copies it to `~/.config/git/ignore` inside the container, git's XDG default, so no `git config` is touched. If the host has no global gitignore the step is a no-op and the container starts normally.

> **Windows hosts:** `initializeCommand` runs a bash script on the host, so native Windows needs Git Bash/WSL on `PATH` — otherwise the sync is skipped but the container still starts.

### Operating modes

- **Default (egress open)** — outbound traffic is unrestricted. Host credentials are *not* bind-mounted (Claude/Codex/`gh` auth lives in container-scoped volumes), and the host Docker socket is not exposed. The defense surface for autonomous agent runs is: non-root `vscode` user, workspace-only mount, container-scoped auth volumes. Codex is seeded with `approval_policy = "never"` and `sandbox_mode = "workspace-write"` in its container-scoped config, which lets it work without pauses while keeping writes scoped to the workspace.
- **Isolated mode (optional)** — for a stricter sandbox, create a Docker network with no egress and attach the container to it:
  ```bash
  docker network create --internal agent-internal
  ```
  Then add `"runArgs": ["--network=agent-internal"]` to a local override (e.g. `.devcontainer/devcontainer.local.json` or a separate workspace). Outbound is fully blocked, so resolve dependencies (`uv sync`, etc.) before switching, and run a proxy sidecar if the agent still needs API access.

### What this isolation *does not* cover

The container compresses the blast radius from "everything the host user can touch" down to "the workspace + container-scoped auth volumes" — but it is still a Linux container, not a microVM. Specifically, this template does **not** provide:

- A separate kernel (a container-escape kernel exploit is not contained).
- Granular network allow/deny lists (only the binary `--network=internal` mode above; the previous iptables-based allowlist was removed because it was hard to keep correct).
- A nested Docker daemon for safely building/running containers from inside the agent session (the host Docker socket is intentionally not mounted).

If you need any of those, run the agent inside a higher-assurance sandbox such as [Docker Sandbox](https://docs.docker.com/ai/sandboxes/) (microVM kernel boundary, allow/deny networking, per-sandbox Docker daemon) and treat this devcontainer as the inner workspace.

**Host loopback access is intentionally not opened.** `host.docker.internal` is not added by default — opening it would expose every `0.0.0.0`-bound host service (local LLM servers, dev DBs, debug dashboards) to the agent. If you specifically need it — e.g. to point Hermes at a locally hosted OpenAI-compatible endpoint — add it as a local override, not a project default:

```jsonc
// .devcontainer/devcontainer.local.json (per-user override; do not commit)
{ "runArgs": ["--add-host=host.docker.internal:host-gateway"] }
```

Then bind the host service to `0.0.0.0` (not `127.0.0.1`) so the bridge network can reach it, and configure the agent (`hermes model`, etc.) to use `http://host.docker.internal:<port>`.

### Restricting GitHub permissions (PAT)

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

### Notes

- Pulling Feature updates: `devcontainer up --workspace-folder . --remove-existing-container` (or VS Code → "Rebuild Container").
- Host Docker socket is intentionally not mounted; the agent cannot manipulate host containers.
