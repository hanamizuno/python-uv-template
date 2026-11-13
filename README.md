# Python + uv + AI Agent Development Template

This repository serves as a template for developing Python applications using the [uv](https://docs.astral.sh/uv/) package manager. It comes pre-configured with Docker, Docker Sandboxes kits for AI agents, GitHub Actions CI, and common development tools.

## Scope

This template targets **non-distributed Python applications** (services, internal tools, scripts) — it is not intended for building distributable libraries or wheels. It provides only the **outer scaffolding** (CI, containers, security tooling); the inner application code is intentionally minimal.

`myapp/` is a placeholder package — rename it and replace its contents with your own. Tests are co-located under each package's `tests/` directory.

## Features

*   **Modern Python Stack:** Uses Python 3.14+ and `uv` for fast dependency management.
*   **Containerized Development:**
    *   **Docker & Docker Compose:** Provides consistent development and production environments using multi-stage builds (`dev`, `prod`).
*   **AI Agent Sandbox:** [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`) kits in `.sandbox/` run agents under stronger isolation — a microVM kernel boundary, deny-by-default networking, and credentials that never enter the VM. Launched from the host.
*   **Development Tools:** Integrated with standard development tools:
    *   [`ruff`](https://docs.astral.sh/ruff/) for linting and formatting.
    *   [`pyright`](https://microsoft.github.io/pyright/) for static type checking.
    *   [`pytest`](https://docs.pytest.org/) for testing (including coverage reports).
    *   [`taskipy`](https://github.com/taskipy/taskipy) for managing project tasks.
*   **CI/CD:** GitHub Actions workflows (`.github/workflows/`) — a consolidated `ci.yml` runs linting, type checking, and tests (with a coverage PR comment) in a single job; companion workflows cover security scanning, SBOM generation, Dockerfile/workflow linting, and labeling.
*   **Pre-commit Hooks:** `.pre-commit-config.yaml` runs ruff, pyright, and a lockfile check at commit time via [prek](https://github.com/j178/prek) (optional).
*   **Shared Knowledge Base:** `docs/knowledge/` is an [OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) bundle — a plain-Markdown knowledge base (ADRs, architecture notes, conventions, runbooks, research) that both humans and AI agents read and write. Ships as a labeled-sample skeleton; start at [`docs/knowledge/index.md`](docs/knowledge/index.md).

## Security

This project implements supply chain attack protections.
cf. https://zenn.dev/dajiaji/articles/47164ff27d2123

- **Lockfile Integrity**: CI uses `uv sync --locked`, which fails when `uv.lock` is missing, tampered with, or out of sync with `pyproject.toml`
- **Minimum Privileges**: Workflows use `permissions: {}` at top level
- **Actions Lockfile**: Every action used by the workflows — including transitive dependencies — is pinned to a verified commit in [`.github/workflows/actions.lock`](https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles), so `uses:` lines reference readable release tags. The runner refuses unlocked actions, `verify_lockfile.yml` checks the lockfile on every workflow change, and Dependabot regenerates the matching entry in its version-update PRs. Docker actions are pinned by `@sha256:` digest, since the lockfile does not cover container images
- **Dependabot Cooldown**: 7-day delay before accepting new package versions
- **Resolution Cooldown**: uv's [`exclude-newer`](https://docs.astral.sh/uv/concepts/resolution/#reproducible-resolutions) is set to `7 days`, so `uv lock` never resolves to packages released within the last 7 days (kept in sync with the Dependabot cooldown)
- **Vulnerability Scanning**: Trivy scans dependencies on dependency/Dockerfile/workflow changes and weekly — PRs fail on CRITICAL/HIGH findings; `push`/`schedule` runs upload SARIF results to the GitHub Security tab
- **SBOM Generation**: CycloneDX SBOM generated on dependency changes
- **Workflow Auditing**: zizmor checks for workflow security issues

> [!NOTE]
> **Using this template in a private repository?** The SARIF upload to the Security tab requires Code scanning, which is free for public repositories but needs [GitHub Code Security](https://docs.github.com/en/code-security) for private ones — without it, the upload step fails with `Resource not accessible by integration`. If you keep your repository private, edit `.github/workflows/security.yml` to always use the table + exit-code approach instead:
>
> 1. Delete the SARIF-format "Run Trivy vulnerability scanner" step and the "Upload Trivy scan results to GitHub Security tab" step.
> 2. Remove the `if: github.event_name == 'pull_request'` condition from the remaining table-format step.
> 3. Remove `security-events: write` from the job's `permissions`.
>
> Alternatively, enable GitHub Code Security on the repository to keep the Security tab integration.

## Directory Structure

```
.
├── .claude/                    # Claude Code settings (permissions.defaultMode: auto)
├── .dockerignore
├── .editorconfig
├── .github/                    # GitHub-specific files
│   ├── copilot-instructions.md # Pointer to AGENTS.md for GitHub Copilot
│   ├── dependabot.yml          # Dependabot configuration
│   ├── ISSUE_TEMPLATE/         # Issue forms (bug, feature, task)
│   ├── labeler.yml             # Path-based PR labeling config (used by label_pr.yml)
│   ├── labels.yml              # Repository label definitions (synced via the manual Sync Labels workflow)
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── scripts/
│   │   └── sync-labels.sh
│   └── workflows/              # GitHub Actions CI workflows
│       ├── actions.lock        # Actions lockfile (generated by `gh actions-lock`; never edit by hand)
│       ├── ci.yml              # Lint + type check + tests (single job)
│       ├── label_pr.yml        # PR auto-labeling (actions/labeler)
│       ├── labels.yml          # Label sync (manual: workflow_dispatch)
│       ├── lint_docker.yml
│       ├── lint_gha.yml
│       ├── sbom.yml            # SBOM generation
│       ├── security.yml        # Vulnerability scanning
│       └── verify_lockfile.yml # Checks actions.lock against the workflows (gh actions-lock --verify)
├── .gitignore
├── .pre-commit-config.yaml     # Pre-commit hooks (run via prek)
├── .python-version             # Specifies Python version (primarily for uv/tooling)
├── .sandbox/                   # Docker Sandboxes (sbx) kits — stronger agent isolation (host-side)
│   ├── claude-auto/            # Fork kit: claude's YOLO default -> --permission-mode auto
│   ├── codex-approve/          # Fork kit: codex's YOLO default -> --approve-for-me
│   ├── kit/                    # Shared mixin kit (uv, Python, prek, Codex CLI, network/credential rules)
│   └── README.md               # sbx setup and host hand-off steps
├── .vscode/                    # VSCode-specific files
│   └── settings.json
├── AGENTS.md                   # Project guidelines for AI agents and humans
├── CLAUDE.md                   # Pointer to AGENTS.md for Claude Code
├── Dockerfile                  # Defines container images (dev, prod)
├── LICENSE
├── README.md                   # This file
├── compose.dev.yml             # Docker Compose configuration for development
├── compose.yml                 # Docker Compose configuration for production
├── docs/
│   └── knowledge/              # Shared knowledge base (OKF bundle): ADRs, conventions, runbooks, ...
├── myapp/                      # Placeholder application package — rename and replace
│   ├── __init__.py
│   ├── main.py                 # Sample application code
│   └── tests/                  # Co-located tests (no __init__.py — uses pytest importlib mode)
│       └── main_test.py
├── pyproject.toml              # Project metadata and tool config (uv, ruff, pyright, pytest, taskipy)
└── uv.lock                     # Pinned versions of dependencies
```

## Adopting This Template

After creating a repository from this template:

1. Rename the `myapp/` package directory to your project's name, then update every reference to it:
    - `pyproject.toml`: `[project] name` and `description`, `--cov=myapp` in the `test_cov` task, `testpaths` under `[tool.pytest.ini_options]`, and `source` under `[tool.coverage.run]`
    - `myapp/tests/main_test.py`: the `from myapp.main import hello` import
2. Fill in the `LICENSE` placeholders (`[yyyy]`, `[name of copyright owner]`) — or replace the license entirely.
3. Replace the sample documents in `docs/knowledge/` with real project knowledge (each sample carries a "replace me" banner).
4. If your repository is private, adjust `.github/workflows/security.yml` as described in [Security](#security) (the Security-tab upload requires GitHub Code Security on private repositories).
5. Run the **Sync Labels** workflow once (Actions → Sync Labels → Run workflow) to create the project labels (e.g. `meta`, used by PR auto-labeling) — label sync is manual-only.
6. Run `uv sync && uv run task lint && uv run task test` to confirm the renamed project is healthy.

## Getting Started

### Prerequisites

*   Docker and Docker Compose
*   [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`) — only for running AI agents (see [below](#ai-agent-sandbox-docker-sandboxes))
*   uv (if not using Docker)

### Setup Options

#### Option 1: Using Docker Compose

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

#### Option 2: Using uv locally (without Docker)
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

### Pre-commit Hooks (optional)

[Install prek](https://github.com/j178/prek?tab=readme-ov-file#installation) (preinstalled in the sbx kit) and run:

```bash
prek install
```

The hooks (defined in `.pre-commit-config.yaml`) run `ruff check`, `ruff format --check`, `pyright`, and `uv lock --check` on each commit.

### Available Tasks (using Taskipy)

Run these tasks via `uv run task <name>` locally, or inside the development container (`docker compose run`):

*   `task lint`: Run linters (`ruff check` and `pyright`).
*   `task fix`: Automatically fix linting issues with `ruff`.
*   `task format`: Format code with `ruff format`.
*   `task test`: Run tests with `pytest`.
*   `task test_cov`: Run tests and generate coverage reports.

Example:
```bash
uv run task lint
uv run task test_cov
```

## AI Agent Sandbox (Docker Sandboxes)

AI coding agents (Claude Code, Codex) run in an isolated environment —
a microVM kernel boundary, deny-by-default networking, and secrets that never enter the VM —
`.sandbox/` ships kits for [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`).
Launch it from the host, e.g.:

```bash
sbx env run ./.sandbox/claude-auto     # Claude Code in auto permission mode
sbx env run ./.sandbox/codex-approve   # Codex in approve-for-me mode
```

`sbx` runs on the host OS. See [`.sandbox/README.md`](.sandbox/README.md) for setup and for getting the work
back to the host; [`docs/knowledge/runbooks/agent-sandbox-sbx.md`](docs/knowledge/runbooks/agent-sandbox-sbx.md)
covers the mechanics (environment files and kit spec v3, why clone mode is mandatory, network policy, secrets, troubleshooting).
