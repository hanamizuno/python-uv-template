# Python + uv + AI Agent Development Template

This repository serves as a template for developing Python applications using the [uv](https://docs.astral.sh/uv/) package manager and potentially leveraging AI agents (like Cline) for development tasks. It comes pre-configured with Docker, Dev Containers, GitHub Actions CI, and common development tools.

## Features

*   **Modern Python Stack:** Uses Python 3.13+ and `uv` for fast dependency management.
*   **Containerized Development:**
    *   **Docker & Docker Compose:** Provides consistent development and production environments using multi-stage builds (`dev`, `prod`).
    *   **VSCode Dev Containers:** Includes a `.devcontainer/devcontainer.json` configuration for a seamless development experience within VSCode.
*   **Development Tools:** Integrated with standard development tools:
    *   [`ruff`](https://docs.astral.sh/ruff/) for linting and formatting.
    *   [`pyright`](https://microsoft.github.io/pyright/) for static type checking.
    *   [`pytest`](https://docs.pytest.org/) for testing (including coverage reports).
    *   [`taskipy`](https://github.com/taskipy/taskipy) for managing project tasks.
*   **CI/CD:** Includes GitHub Actions workflows (`.github/workflows/`) for automated linting and testing on code pushes.
*   **(WIP) AI Agent Integration (Workflow Example):**
    *   Designed to work with AI agents for planning and executing development tasks.
    *   Manages prompts and execution plans in Markdown format within the `docs/` directory.

## Important Notes

### Dependency Management with Dependabot

Due to [Dependabot not yet supporting PEP 735 `[dependency-groups]`](https://github.com/dependabot/dependabot-core/issues/10847), this project uses `[project.optional-dependencies]` instead. When adding dependencies, please note:

#### Adding Runtime Dependencies
```bash
# Add to [project.dependencies]
uv add <package>
```

#### Adding Development Dependencies
```bash
# Add to [project.optional-dependencies] dev group
uv add --optional dev <package>
```

#### Installing Dependencies
```bash
# Install all dependencies including dev
uv sync --all-extras

# Or using pip-compatible command
uv pip install -e ".[dev]"
```

Once Dependabot supports `[dependency-groups]`, we plan to migrate back to the more modern PEP 735 format.

## Directory Structure

```
.
├── .devcontainer/        # VSCode Dev Containers configuration
│   ├── compose.yml
│   └── devcontainer.json
├── .dockerignore
├── .editorconfig
├── .github/              # GitHub specific files
│   ├── dependabot.yml    # Dependabot configuration
│   └── workflows/        # GitHub Actions CI workflows
│       ├── lint_docker.yml
│       ├── lint_gha.yml
│       ├── lint.yml
│       └── test.yml
├── .vscode/              # VSCode specific files
│   └── settings.json     # VSCode settings
├── .gitignore
├── .python-version       # Specifies Python version (primarily for uv/tooling)
├── Dockerfile            # Defines container images (dev, prod, devcontainer)
├── compose.dev.yml       # Docker Compose configuration for development
├── compose.yml           # Docker Compose configuration for production
├── pyproject.toml        # Project metadata and dependencies (PEP 621, uv, ruff, pyright, pytest, taskipy)
├── README.md             # This file
├── uv.lock               # Pinned versions of dependencies
├── docs/                 # Documentation and AI agent related files
│   └── plans/            # Stores execution plans for development tasks (e.g., *.md)
│       ├── 20250414_update_python_version_plan.md # Example plan
│       └── 20250414_update_readme_plan.md        # Example plan
├── htmlcov/              # HTML coverage reports (generated by pytest-cov)
└── src/                  # Source code directory
    ├── __init__.py
    ├── main.py           # Sample application code
    └── tests/            # Test code directory
        ├── __init__.py
        └── main_test.py  # Tests for main.py
```

## Getting Started

### Prerequisites

*   Docker and Docker Compose
*   VSCode with the "Dev Containers" extension (recommended)
*   uv (if not using Docker)

### Setup Options

#### Option 1: Using VSCode Dev Containers (Recommended)

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

## AI Agent Workflow Example

(WIP)
