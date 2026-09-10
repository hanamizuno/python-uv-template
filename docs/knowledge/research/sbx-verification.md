---
type: Reference
title: sbx — known and unverified facts for this template
description: Environment facts inherited from the sibling pnpm-biome-template's hardware verification, what this repository's own sandbox has measured, and what is still unverified
tags: [sbx, agents]
timestamp: 2026-09-05T00:00:00Z
---

# sbx — known and unverified facts for this template

The `spec.yaml` files follow the [kit spec reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference/).

## Inherited from the sibling pnpm-biome-template (verified on hardware there)

Verified on the claude template (`docker/sandbox-templates:claude-code-docker`). These are facts about sbx itself, so they should carry over, but have **not** been re-measured for this Python/uv kit:

* Base is Ubuntu 26.04/arm64, bundled Node v22, `~/.codex` starts empty (so the config seed takes effect), the agent user has passwordless sudo and is in the docker group, and Docker inside the VM is 29.7.1.
* `${WORKDIR}` in `~/.codex/config.toml` expands to the workspace's absolute path; in clone mode this mirrors the host's path, matching direct mode. The template's own `/home/agent/workspace` is left as an unused empty directory.
* `git push` over HTTPS works via header injection (`format: "token %s"`) — both `gh api user` and `git push` succeed; no need to fall back to pushing from the host.
* Deny-by-default networking is in effect (domains outside the allowlist return 403 `no matching allow rule`). `GH_TOKEN` holds a 13-character sentinel (`proxy-managed`); the real value is not in the VM.
* Built-in agent auth is proxy-managed: `claudeAiOauth.accessToken`/`refreshToken` in `~/.claude/.credentials.json` are 26-character sentinels — real OAuth tokens don't enter the VM.
* The built-in claude template's default launch command is `claude --dangerously-skip-permissions` (measured with `ps`); a shared mixin can't override it (no `sandbox:` block).
* Approach A ([agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md)) was verified there: `sbx create` completes the kit install without launching the agent, `sbx exec` shows `claude --permission-mode auto` in `ps` with no bypass flag, and subscription auth survives with no re-login.
* The default policy does not allow `console.anthropic.com`/`claude.ai` (measured: 403) — the kit adds them.
* `pkill -f <pattern>` inside the VM kills your own shell too, because the full command line matches — `agentInstructions` says to kill by PID instead.
* `claude mcp add` defaults to `local` scope (per-cwd); since an install step's cwd isn't necessarily the workspace, a default-scope registration won't show in `claude mcp list`. This kit registers no MCP servers, but use `-s user` if one is added later.
* `claude mcp list` shows an `mcp-gateway` entry (`http://mcp-gateway.docker.internal/mcp`) from sbx itself, not from any kit, with a warning that claude.ai connectors are disabled because "another auth source is set" — that's the proxy-managed credential. Only claude.ai organization connectors are affected; Claude Code itself is unaffected.

## Measured in this repository's own sandbox (2026-09-10)

Read from inside `claude-python-uv-template`, a sandbox created from this kit on the claude template with approach A. This is the first hardware run of the Python/uv kit itself.

* **Approach A works with this kit.** `ps -eo args` shows `claude --permission-mode auto` with no bypass flag, and the session runs with no login performed inside the VM. `/run/sandbox/source` is present and the workspace is a clone, as expected in clone mode.
* **Every install step took effect.** uv 0.9.26 (`/usr/local/bin/uv`), `/etc/profile.d/10-uv-local-bin.sh`, prek 0.5.2 (`~/.local/bin/prek`), Codex CLI 0.149.1 at the npm global path (the pinned version, so the kit installed it), and the `codex@openai-codex` plugin registered at user scope and enabled.
* **The base image matches the sibling's readings** — Ubuntu 26.04 LTS aarch64, bundled Node v22.22.1.
* **`~/.codex/config.toml` is the kit's seed**, with `${WORKDIR}` expanded to the host path (`/Users/…/python-uv-template`) — so the claude template seeds no Codex config and `onlyIfMissing` does not shadow it.
* **`uv sync --frozen` → `uv run task lint` → `uv run task test_cov` all pass** (ruff and pyright clean; 3 tests, 100% coverage) on the uv-managed CPython 3.14.2. `prek install` is genuinely needed first — the clone carries no git hook — and the `secretlint` hook then runs on commit.
* **GitHub header injection works from the VM**: `git push` over HTTPS and `gh pr create` both succeed with no real token in the environment. The inherited `origin` is an SSH URL and fails — see the runbook's auth troubleshooting.
* **`claude mcp list` differs from the sibling reading**: the `mcp-gateway` entry is present but fails with `HTTP 503: MCP gateway is not running for this sandbox`, and the claude.ai connectors (Gmail / Calendar / Drive) connect normally, with no "another auth source is set" warning. Nothing here depends on either.

## Not yet verified for this repository

Update `spec.yaml` and this section as these are learned:

1. **The host-side half of the first-run checklist** — `sbx version` / `login` / `kit validate`, and `sbx secret ls` showing sandbox rather than global scope. Everything measurable from inside the VM is covered above. See the first-run checklist in [agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md).
2. ~~**Whether uv's managed CPython download passes the network policy.**~~ Resolved: `uv python install 3.14` fetched cpython-3.14.2 into `~/.local/share/uv/python/` during the kit install, so python-build-standalone is reachable under the allowlist as written.
3. **Whether the sandbox template already ships `uv`** — still undecided: the binary sits at `/usr/local/bin/uv`, which is exactly the kit's own `UV_INSTALL_DIR`, so its presence proves nothing either way. The image does ship a system CPython 3.14.4 at `/usr/bin/python3.14`, but uv's managed 3.14.2 is what the project actually runs on.
4. **Behavior on the codex template** — checks above only covered the claude template. If the codex template already seeds `~/.codex/config.toml`, `onlyIfMissing` means the kit's settings won't apply.
5. **Whether secrets survive `sbx rm`** — unverified whether a sandbox-scoped secret persists after recreation. Re-check with `gh api user` after recreating.
6. **Approach B is unverified** (approach A is now verified both here and on the sibling template; B has never been run). Confirm `sbx kit validate` passes, both `--kit` args apply, `--dangerously-skip-permissions` is gone from launch args, and where the OAuth limitation actually shows up — always measure with `ps`, since `entrypoint`/`command` inheritance resolution isn't documented.

---

Last verified: 2026-09-10 (this repository's own sandbox); 2026-09-05 for the inherited section
