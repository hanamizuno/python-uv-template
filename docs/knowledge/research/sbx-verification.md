---
type: Reference
title: sbx — known and unverified facts for this template
description: What has been measured for this repository's kit spec v3 kit and environment files on sbx v0.51.0, what carried over from the v2 era, and what is still unverified
tags: [sbx, agents]
timestamp: 2026-11-09T00:00:00Z
---

# sbx — known and unverified facts for this template

The kit follows [kit spec v3](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md); the launchers are [environment files](https://docs.docker.com/ai/sandboxes/configuration/environment-files/). Mechanics: [agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md).

## Measured on sbx v0.51.0 (2026-11-09, macOS / Apple Silicon)

Throwaway sandboxes created with `sbx env create` from this repository's environment files, then removed.

* **`sbx kit validate ./.sandbox/kit` passes** and `sbx env plan` resolves both environment files (and the `host-claude` overlay merged on top: `cmd` replaced, postCreate added).
* **The base is different from v2.** The built-in claude/codex kits run on Docker Hardened Images (Debian 13, aarch64) with **16K memory pages**. `~/.local/bin` is already on PATH; there is no Node/npm.
* **The image's `/usr/bin/uv` (Debian package 0.13.7) aborts** with `<jemalloc>: Unsupported system page size`. The official astral build of the same version runs, so the kit installs it into `/usr/local/bin`. Root hooks search `/usr/bin` first, so the hook checks `/usr/local/bin/uv` by absolute path; the agent's PATH has `/usr/local/bin` first.
* **Every install hook succeeds** on both the claude and codex kits: uv, `uv python install 3.14` (cpython-3.14.10 into `~/.local/share/uv/python/`, so python-build-standalone is reachable through `install.allow`), prek, Node 24 from NodeSource, Codex CLI 0.149.1, the `codex@openai-codex` plugin (1.0.6, user scope), and the Codex seed with `[projects."<host path>"]` from `WORKSPACE_DIR`.
* **`uv sync --frozen` → `uv run task lint` → `uv run task test_cov` pass** in the VM (ruff and pyright clean; 3 tests, 100% coverage), and `prek install` installs the git hook.
* **The launch override works.** Under `sbx env run`, `ps -eo args` shows `claude --permission-mode auto` (with the overlay: `… --settings /home/agent/.claude/host-settings.json`) and `codex --approve-for-me` — no bypass flag in either.
* **The built-in codex kit seeds `~/.codex/config.toml` first** (`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`), so the kit's seed is skipped there. `codex --help` documents `--approve-for-me` as "automatic review using the workspace-write sandbox", so the launch flag overrides both.
* **The `host-claude` overlay works**: its postCreate runs `stage-host-claude.sh` on the host, and `sbx cp` lands `host-settings.json` (0644) and `statusline-command.sh` (0755) in `~/.claude/`, owned by the host uid.
* **Network**: `example.com` gets a 403 with the body `Approval required for example.com:443.`; `pypi.org` is reachable. `GH_TOKEN` is the 13-character sentinel `proxy-managed` even with no secret registered.
* **A secret registered after creation applies immediately.** With no secret, `api.github.com/user` answers "Requires authentication"; right after `sbx secret set github --sandbox <name>` (dummy token) it answers "Bad credentials" — the header is injected, with no restart. `sbx env rm` removes the sandbox's secrets and its `sandbox-<name>` git remote.
* **Mounts**: `~/.claude/skills` is a read-only virtiofs mount. `additionalWorkspaces` with `readOnly: true` mounts at the host path and refuses writes; `~` in its `path` is *not* expanded (it resolves relative to the file).
* **git identity is not inherited** (`user.name`/`user.email` unset; `core.excludesFile` is set).
* **The built-in opencode kit cannot compose with this kit**: it uses `agent-context@1`, this kit `@2` (measured on the sibling pnpm-biome-template).

## Carried over from the v2 era (not re-measured on v3)

* `git push` over HTTPS works via header injection, and `gh pr create` succeeds; the inherited SSH `origin` fails (see the runbook's auth troubleshooting).
* `pkill -f <pattern>` inside the VM kills your own shell, because the full command line matches.
* `claude mcp add` defaults to `local` (per-cwd) scope, so an install hook must use `-s user` (this kit registers no MCP server; the sibling's does, and it works on v3).
* Built-in agent auth is proxy-managed: OAuth tokens in `~/.claude/.credentials.json` are sentinels.

## Not yet verified for this repository

Update the kit and this section as these are learned:

1. **Real GitHub round-trip on v3** — `gh api user` with a real PAT, and `git push` over HTTPS from the VM.
2. **Subscription auth through `sbx env run`** — that Claude Max / ChatGPT sessions work with no re-login (the checks above stopped at the launch command).
3. **Whether `--settings` applies the host statusline** under the overlay.
4. **Inside the codex sandbox, Claude-less paths** — whether anything there starts `codex` without `--approve-for-me` (and so under the codex kit's YOLO seed).

---

Last verified: 2026-11-09 (sbx v0.51.0)
