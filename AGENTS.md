# Repository Guidelines

## Project Structure & Module Organization
- Source: `src/` (entry example: `src/main.py`).
- Tests: `src/tests/` with `*_test.py` files (e.g., `src/tests/main_test.py`).
- Docs & plans: `docs/` (e.g., `docs/plans/*.md`).
- Tooling: `pyproject.toml` manages deps and tasks; `uv.lock` pins versions.
- Containers: `Dockerfile`, `compose.dev.yml` (dev), `compose.yml` (prod).

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
- Python 3.13+, 4-space indentation, type hints required (Pyright strict).
- Lint/format: Ruff is the single source of truth (`task lint`, `task format`).
- Docstrings: Google style (configured via Ruff/pydocstyle).
- Naming: modules/packages `snake_case`; classes `PascalCase`; functions/vars `snake_case`.
- Keep public APIs small; prefer pure functions in `src/` and minimal side effects.

## Testing Guidelines
- Framework: Pytest with simple `assert` style.
- Location/naming: place tests in `src/tests/`, name files `*_test.py`, tests `test_*`.
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

