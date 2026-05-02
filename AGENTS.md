# Repository Guidelines

## Project Structure & Module Organization
- Source: top-level package (placeholder: `myapp/`, e.g., `myapp/main.py`). Rename for your project.
- Tests: co-located under each package's `tests/` directory with `*_test.py` files (e.g., `myapp/tests/main_test.py`). `tests/` directories intentionally have no `__init__.py` (pytest `--import-mode=importlib`).
- Docs & plans: `docs/` (e.g., `docs/agents/*.md`).
- Tooling: `pyproject.toml` manages deps and tasks; `uv.lock` pins versions.
- Containers: `Dockerfile`, `compose.dev.yml` (dev), `compose.yml` (prod), `compose.claude.yml` (Claude Code; see `claude/README.md`).

## Build, Test, and Development Commands
- Install (local uv): `uv sync` (dev deps included).
- Run tasks (local): `uv run task <name>` (e.g., `uv run task test`).
- Common tasks (via Taskipy):
  - `task lint`: Ruff + Pyright checks.
  - `task fix`: Ruff autofix.
  - `task format`: Ruff formatter.
  - `task test`: Run pytest.
  - `task test_cov`: Pytest with coverage (HTML at `htmlcov/`).
- Dev container (VS Code): “Reopen in Container”, then run `task ...` in terminal.
- Docker Compose (dev): `docker compose -f compose.dev.yml run --rm app task test`.

## Coding Style & Naming Conventions
- Python 3.14+, 4-space indentation, type hints required (Pyright strict).
- Lint/format: Ruff is the single source of truth (`task lint`, `task format`).
- Docstrings: Google style (configured via Ruff/pydocstyle).
- Naming: modules/packages `snake_case`; classes `PascalCase`; functions/vars `snake_case`.
- Keep public APIs small; prefer pure functions in `src/` and minimal side effects.

## Testing Guidelines
- Framework: Pytest with simple `assert` style.
- Location/naming: place tests in `tests/` co-located with the source they cover, name files `*_test.py` (or `test_*.py`), tests `test_*`.
- Do not add `__init__.py` to `tests/` directories — pytest is configured with `--import-mode=importlib` to allow same-named test files across multiple `tests/` dirs.
- Coverage: use `task test_cov`; include edge cases and type-related tests.
- Fast tests by default; mark slow/external I/O as separate or mock.

## Commit & Pull Request Guidelines
- Commit style: Prefer Conventional Commits when possible
  - Examples: `feat: add greeting cli`, `fix: correct None handling`, `chore: update uv.lock`.
- Before PR: run `task lint` and `task test` locally/inside container and fix issues.
- PR description: purpose, summary of changes, how to test, related issues (`Closes #123`).
- Include screenshots or logs when changing behavior or CLI output.

## Security & Configuration Tips
- Do not commit secrets; prefer env vars and Compose overrides.
- Pin dependencies via `uv.lock`; update with care (`uv sync --upgrade`).
- CI runs lint/tests via GitHub Actions; keep pipeline green before merging.

