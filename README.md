# Python + uv + AI Agent Development Template

This repository serves as a template for developing Python applications using the [uv](https://docs.astral.sh/uv/) package manager. It comes pre-configured with Docker, Dev Containers, GitHub Actions CI, and common development tools.

## Scope

This template targets **non-distributed Python applications** (services, internal tools, scripts) — it is not intended for building distributable libraries or wheels. It provides only the **outer scaffolding** (CI, containers, security tooling); the inner application code is intentionally minimal.

`myapp/` is a placeholder package — rename it and replace its contents with your own. Tests are co-located under each package's `tests/` directory.

## Features

*   **Modern Python Stack:** Uses Python 3.14+ and `uv` for fast dependency management.
*   **Containerized Development:**
    *   **Docker & Docker Compose:** Provides consistent development and production environments using multi-stage builds (`dev`, `prod`, `devcontainer`).
    *   **VSCode Dev Containers:** Includes a `.devcontainer/devcontainer.json` configuration that layers the AI agent toolchain (Claude Code CLI, Codex CLI, GitHub CLI, common utilities) on top of the project's Python environment via [Dev Container Features](https://containers.dev/implementors/features/) and post-create setup.
*   **Development Tools:** Integrated with standard development tools:
    *   [`ruff`](https://docs.astral.sh/ruff/) for linting and formatting.
    *   [`pyright`](https://microsoft.github.io/pyright/) for static type checking.
    *   [`pytest`](https://docs.pytest.org/) for testing (including coverage reports).
    *   [`taskipy`](https://github.com/taskipy/taskipy) for managing project tasks.
*   **CI/CD:** GitHub Actions workflows (`.github/workflows/`) — a consolidated `ci.yml` runs linting, type checking, and tests (with a coverage PR comment) in a single job; companion workflows cover security scanning, SBOM generation, Dockerfile/workflow linting, and labeling.
*   **Pre-commit Hooks:** `.pre-commit-config.yaml` runs ruff, pyright, and a lockfile check at commit time via [prek](https://github.com/j178/prek) — set up automatically in the Dev Container, optional elsewhere.
*   **Shared Knowledge Base:** `docs/knowledge/` is an [OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) bundle — a plain-Markdown knowledge base (ADRs, architecture notes, conventions, runbooks, research) that both humans and AI agents read and write. Ships as a labeled-sample skeleton; start at [`docs/knowledge/index.md`](docs/knowledge/index.md).

## Security

This project implements supply chain attack protections.
cf. https://zenn.dev/dajiaji/articles/47164ff27d2123

- **Lockfile Integrity**: CI uses `uv sync --locked`, which fails when `uv.lock` is missing, tampered with, or out of sync with `pyproject.toml`
- **Minimum Privileges**: Workflows use `permissions: {}` at top level
- **SHA Pinning**: All GitHub Actions are pinned to commit SHAs
- **Dependabot Cooldown**: 7-day delay before accepting new package versions
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
├── .devcontainer/              # Dev Container config (also runs the AI agent toolchain via Features)
│   ├── codex-config.toml       # Initial Codex CLI config copied into the persisted ~/.codex volume
│   ├── compose.yaml            # Devcontainer compose definition (merged with git-ignored compose.local.yaml)
│   ├── devcontainer.json
│   ├── initialize.sh           # Host-side hook: stages host git/Claude config for the container
│   ├── post-create.sh
│   ├── post-start.sh
│   └── README.md               # AI agent toolchain, auth, isolation modes, PAT setup
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
│       ├── ci.yml              # Lint + type check + tests (single job)
│       ├── label_pr.yml        # PR auto-labeling (actions/labeler)
│       ├── labels.yml          # Label sync (manual: workflow_dispatch)
│       ├── lint_docker.yml
│       ├── lint_gha.yml
│       ├── sbom.yml            # SBOM generation
│       └── security.yml        # Vulnerability scanning
├── .gitignore
├── .pre-commit-config.yaml     # Pre-commit hooks (run via prek)
├── .python-version             # Specifies Python version (primarily for uv/tooling)
├── .vscode/                    # VSCode-specific files
│   └── settings.json
├── AGENTS.md                   # Project guidelines for AI agents and humans
├── CLAUDE.md                   # Pointer to AGENTS.md for Claude Code
├── Dockerfile                  # Defines container images (dev, prod, devcontainer)
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

### Pre-commit Hooks (optional outside the Dev Container)

The Dev Container registers the git pre-commit hooks automatically (see `.devcontainer/post-create.sh`). If you work outside the container, [install prek](https://github.com/j178/prek?tab=readme-ov-file#installation) and run:

```bash
prek install
```

The hooks (defined in `.pre-commit-config.yaml`) run `ruff check`, `ruff format --check`, `pyright`, and `uv lock --check` on each commit.

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

The Dev Container also serves as the runtime for AI coding agents (Claude Code, Codex, etc.) — toolchain, authentication, host config inheritance, isolation modes, and scoped GitHub PAT setup are documented in [`.devcontainer/README.md`](.devcontainer/README.md).
