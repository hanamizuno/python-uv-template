---
type: Reference
title: sbx — known and unverified facts for this template
description: Environment facts inherited from the sibling pnpm-biome-template's hardware verification, vs. what's unverified for this Python/uv kit
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
* Approach A ([sbx-setup-and-yolo-override.md](/docs/knowledge/runbooks/sbx-setup-and-yolo-override.md)) was verified there: `sbx create` completes the kit install without launching the agent, `sbx exec` shows `claude --permission-mode auto` in `ps` with no bypass flag, and subscription auth survives with no re-login.
* The default policy does not allow `console.anthropic.com`/`claude.ai` (measured: 403) — the kit adds them.
* `pkill -f <pattern>` inside the VM kills your own shell too, because the full command line matches — `agentInstructions` says to kill by PID instead.
* `claude mcp add` defaults to `local` scope (per-cwd); since an install step's cwd isn't necessarily the workspace, a default-scope registration won't show in `claude mcp list`. This kit registers no MCP servers, but use `-s user` if one is added later.
* `claude mcp list` shows an `mcp-gateway` entry (`http://mcp-gateway.docker.internal/mcp`) from sbx itself, not from any kit, with a warning that claude.ai connectors are disabled because "another auth source is set" — that's the proxy-managed credential. Only claude.ai organization connectors are affected; Claude Code itself is unaffected.

## Not yet verified for this repository

Update `spec.yaml` and this section as these are learned:

1. **The whole host trial checklist** — nothing in this Python/uv kit has been run on hardware yet. See [sbx-host-trial-checklist.md](/docs/knowledge/runbooks/sbx-host-trial-checklist.md).
2. **Whether uv's managed CPython download passes the network policy.** python-build-standalone is served from GitHub release assets, and the serving host has changed over time — the allowlist carries both `objects.githubusercontent.com` and `release-assets.githubusercontent.com` for that reason. First thing to check if `uv python install 3.14` fails during kit install.
3. **Whether the sandbox template already ships `uv`** — every install step is guarded so it works either way, but worth confirming the pinned Python version and install path.
4. **Behavior on the codex template** — checks above only covered the claude template. If the codex template already seeds `~/.codex/config.toml`, `onlyIfMissing` means the kit's settings won't apply.
5. **Whether secrets survive `sbx rm`** — unverified whether a sandbox-scoped secret persists after recreation. Re-check with `gh api user` after recreating.
6. **Approach B is unverified** (only approach A was verified, on the sibling template). Confirm `sbx kit validate` passes, both `--kit` args apply, `--dangerously-skip-permissions` is gone from launch args, and where the OAuth limitation actually shows up — always measure with `ps`, since `entrypoint`/`command` inheritance resolution isn't documented.

---

Last verified: 2026-09-05
