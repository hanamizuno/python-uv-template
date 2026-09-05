# AI Agent Dev Container

The Dev Container also serves as the runtime for AI coding agents (Claude Code, Codex, etc.). It is Docker Compose based: `./compose.yaml` defines the container, `devcontainer.json` layers the agent toolchain on top via [Dev Container Features](https://containers.dev/implementors/features/) and post-create setup, and the git-ignored `./compose.local.yaml` carries per-user overrides (see below). (`./compose.yaml` is devcontainer-only; the root `compose.yml` / `compose.dev.yml` are separate.)

For the mechanics and security model behind this container — host config inheritance, isolation modes and their limits, `.venv`/uv-cache isolation — see [`docs/knowledge/architecture/devcontainer-agent-runtime.md`](/docs/knowledge/architecture/devcontainer-agent-runtime.md).

## Included agent tooling

- Common utilities (non-root `vscode` user, sudo, packages) — `ghcr.io/devcontainers/features/common-utils:2`
- GitHub CLI — `ghcr.io/devcontainers/features/github-cli:1`
- Node.js (required by `claude-code`) — `ghcr.io/devcontainers/features/node:2`
- Claude Code CLI — `ghcr.io/anthropics/devcontainer-features/claude-code:1`
- Codex CLI — installed by `./post-create.sh` (`npm install -g @openai/codex`)
- Codex plugin for Claude Code — installed by `./post-create.sh` (`claude plugin install codex@openai-codex`), so Claude Code can delegate to Codex on demand (the `codex-rescue` subagent + `/codex` skills)

To add another agent CLI (e.g. Cursor), use an upstream Feature, a local `./<feature-id>/` directory referenced from `features`, or an idempotent install step in `./post-create.sh`.

## Initial setup

1. **Open the container** — VS Code "Reopen in Container", or headless: `devcontainer up --workspace-folder .`
2. **Authenticate** (one-time; persisted in the `claude-config` / `codex-config` / `gh-config` compose volumes):
   - **Claude Code** — just start it; login shows inline on first launch. Don't pass `/login` as a CLI arg — that's a slash command for an active session and triggers the flow twice from the host shell.
     ```bash
     devcontainer exec --workspace-folder . claude --dangerously-skip-permissions
     ```
   - **Codex CLI** — start it and sign in with ChatGPT, or set `OPENAI_API_KEY` in the container.
     ```bash
     devcontainer exec --workspace-folder . codex
     ```
   - **GitHub CLI**:
     ```bash
     devcontainer exec --workspace-folder . gh auth login --hostname github.com --git-protocol https --web
     ```
     To scope this token down instead of using your everyday one, see [`devcontainer-github-pat.md`](/docs/knowledge/runbooks/devcontainer-github-pat.md).

Task secrets (API keys, tokens) for commands the agent runs are delivered via Proton Pass (`pass-cli`), not ambient env — usage is in `AGENTS.md`; one-time host setup and full mechanics are in [`devcontainer-secrets-proton-pass.md`](/docs/knowledge/runbooks/devcontainer-secrets-proton-pass.md).

## Local overrides (compose.local.yaml)

`./compose.local.yaml` (git-ignored) carries your personal-environment diff — extra bind mounts, networks, `extra_hosts` — on top of the committed config; `initialize.sh` auto-generates a no-op stub if it's missing. Paths resolve relative to `.devcontainer/`, so a sibling directory is `../../<name>`:

```yaml
# .devcontainer/compose.local.yaml (per-user override; git-ignored)
services:
  app:
    volumes:
      - ../../reference-docs:/reference-docs:ro
```

## Notes

- This is a container, not a microVM — see the architecture note linked above for what its isolation does and doesn't cover. For that boundary, this repository also ships Docker Sandboxes (`sbx`) kits in `.sandbox/` — see [`.sandbox/README.md`](/.sandbox/README.md).
- Pulling Feature updates: `devcontainer up --workspace-folder . --remove-existing-container` (or VS Code → "Rebuild Container").
- Host Docker socket is intentionally not mounted; the agent cannot manipulate host containers.
