---
type: Architecture Note
title: Dev Container as AI agent runtime
description: How the devcontainer inherits host config, its isolation modes, and the limits of that isolation
tags: [devcontainer, agents, security]
timestamp: 2026-09-05T00:00:00Z
---

# Dev Container as AI agent runtime

The Dev Container (`.devcontainer/`) doubles as the sandboxed runtime for AI coding agents (Claude Code, Codex). See [`.devcontainer/README.md`](/.devcontainer/README.md) for setup steps; this note covers the mechanics and security model behind it.

## Host config inheritance

On every container create/start, `./initialize.sh` (an `initializeCommand`, runs on the host) stages selected host config into git-ignored files, and `./post-start.sh` seeds them inside the container:

* **Global gitignore** — resolved via `core.excludesFile` → `~/.config/git/ignore` (XDG) → `~/.gitignore`, dereferencing symlinks; staged as `./host-gitignore`, copied to `~/.config/git/ignore` in the container. Overwritten on every start — the host is the source of truth.
* **Git identity** — `user.name`/`user.email` read from the host's global git config (values only, not includes or credential helpers), staged as `./host-gituser`, applied via `git config --global` on every start. Keys unset on the host are left alone.
* **Claude Code settings + statusline** — `~/.claude/settings.json` is staged with host-home paths rewritten to `/home/vscode` and deep-merged (via `jq`, host wins per key, container-only keys survive) into the container's copy. Auth/state (`~/.claude.json`, credentials) is intentionally not staged — it stays in the container-scoped volume.

If a host file doesn't exist, its step is a no-op. The staged `host-*` files are git-ignored personal config — a plain filesystem copy (`cp -r`, zip) of the repo would carry them, so exclude them when copying this template outside git.

## Operating modes

* **Default (egress open)** — outbound traffic is unrestricted. Agent auth (Claude/Codex/`gh`) lives in container-scoped volumes rather than being bind-mounted from the host, and the host Docker socket is not exposed. Codex runs with `approval_policy = "never"` / `sandbox_mode = "workspace-write"`, so it works without pauses while keeping writes scoped to the workspace. Because agents run unattended with network access, task secrets are injected per-command via `pass-cli run` instead of sitting in ambient env — see [devcontainer-secrets-proton-pass.md](/docs/knowledge/runbooks/devcontainer-secrets-proton-pass.md).
* **Isolated mode** — for a stricter sandbox, attach the container to a Docker network with no egress:
  ```bash
  docker network create --internal agent-internal
  ```
  ```yaml
  # .devcontainer/compose.local.yaml
  services:
    app:
      networks: [agent-internal]
  networks:
    agent-internal:
      external: true
  ```
  Resolve dependencies (`uv sync`, etc.) before switching; run a proxy sidecar if the agent still needs API access.

## Isolation limits

The container compresses the blast radius from "everything the host user can touch" down to "the workspace + container-scoped auth volumes" — but it is still a Linux container, not a microVM. It does **not** provide:

* A separate kernel (a container-escape kernel exploit is not contained).
* Granular network allow/deny lists (only the binary `--network=internal` mode above; a previous iptables-based allowlist was removed as hard to keep correct).
* A nested Docker daemon for building/running containers from inside the agent session (the host socket is intentionally not mounted).

For any of those, run the agent inside a higher-assurance sandbox such as [Docker Sandbox](https://docs.docker.com/ai/sandboxes/) (microVM kernel boundary, allow/deny networking, per-sandbox Docker daemon) and treat this devcontainer as the inner workspace. This repository ships Docker Sandboxes (`sbx`) kits for exactly that in `.sandbox/` — see [sbx-agent-sandbox.md](/docs/knowledge/architecture/sbx-agent-sandbox.md) and [ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md).

`host.docker.internal` is intentionally not added by default — opening it would expose every `0.0.0.0`-bound host service (local LLM servers, dev DBs, debug dashboards) to the agent. Add it as a local override only when specifically needed:

```yaml
# .devcontainer/compose.local.yaml
services:
  app:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Then bind the host service to `0.0.0.0` (not `127.0.0.1`) so the bridge network can reach it, and point the agent at `http://host.docker.internal:<port>`.

## .venv and uv cache isolation

`.venv` contains platform-specific binaries (the CPython interpreter, native wheels), so sharing it between the host (e.g. macOS) and the container (Linux) forces a reinstall on every switch. A compose volume (`venv`) masks the host's `.venv` on the bind mount — the host keeps its own venv, the container keeps a Linux venv, neither needs reinstalling on switch. A second volume (`uv-cache`) is mounted at `~/.cache/uv` so downloaded wheels survive rebuilds; `UV_LINK_MODE=copy` (set in the Dockerfile) means the volume boundary is copies instead of hardlinks.

To reset the environment: `rm -rf .venv && uv sync --frozen` inside the container (host unaffected). For a fully fresh start, remove the volumes with `docker volume rm` and rebuild.

## Related

* [.devcontainer/README.md](/.devcontainer/README.md) — setup steps
* [devcontainer-github-pat.md](/docs/knowledge/runbooks/devcontainer-github-pat.md) — scoping the GitHub token
* [devcontainer-secrets-proton-pass.md](/docs/knowledge/runbooks/devcontainer-secrets-proton-pass.md) — task secrets flow
