---
type: Architecture Note
title: sbx (Docker Sandboxes) as an agent runtime
description: How sbx isolates agents, clone-mode mechanics, credential model, and how it relates to the Dev Container
tags: [sbx, agents, security]
timestamp: 2026-09-05T00:00:00Z
---

# sbx (Docker Sandboxes) as an agent runtime

See [`.sandbox/README.md`](/.sandbox/README.md) for setup steps. This note covers the mechanics behind it, and how it relates to the [Dev Container](/docs/knowledge/architecture/devcontainer-agent-runtime.md).

## Why sbx, and what it adds

The Dev Container uses a Linux container as its isolation boundary, which — per [devcontainer-agent-runtime.md](/docs/knowledge/architecture/devcontainer-agent-runtime.md) — provides no separate kernel, no granular network allow/deny, and no nested Docker. sbx is the higher-assurance sandbox that fills those gaps:

- **microVM boundary** — a separate kernel, so kernel vulnerabilities that lead to container escape are contained.
- **Deny-by-default networking** — outbound TCP only reaches domains on an allowlist (UDP/ICMP blocked).
- **Credentials stay out of the VM** — API keys/tokens are injected into HTTP headers by the host-side proxy; the real values never enter the VM.
- **A Docker daemon per sandbox** — the agent can build/run containers without touching the host's Docker.

What the kit ([kit/spec.yaml](/.sandbox/kit/spec.yaml)) installs at sandbox creation: `uv` (if missing), Python 3.14 via `uv python install` (matching `.python-version`), `prek`, the Codex CLI plus its Claude Code plugin registration, an initial Codex config seed, and the network-allowlist/credential wiring. `uv sync` and `prek install` are left to the agent (via the kit's `agentInstructions`) since an install step's cwd isn't necessarily the workspace.

## Overriding the built-in YOLO launch commands

Both `claude` and `codex` sbx templates default to bypassing all permissions (`--dangerously-skip-permissions` / `--dangerously-bypass-approvals-and-sandbox`). Passing flags through `sbx run ... --` does not help — they get appended *after* the defaults, so the bypass flag survives. See [sbx-setup-and-yolo-override.md](/docs/knowledge/runbooks/sbx-setup-and-yolo-override.md) for the two ways to actually replace them (approach A: `sbx create` + `sbx exec`, keeps subscription OAuth; approach B: fork kits, requires API-key billing).

`../.claude/settings.json` (`permissions.defaultMode: "auto"`) and the Codex seed here (`approval_policy = "on-request"` / `approvals_reviewer = "auto_review"`) encode the same policy, but launch flags are stronger — under sbx, the effective value is decided by whichever override approach is used. The config files apply when the launch command isn't involved (Dev Container, host, or when Claude delegates to Codex). Note the Codex seed here deliberately differs from `.devcontainer/codex-config.toml` (`approval_policy = "never"`) — aligning the two is an open question.

## Running in clone mode

`sbx run`/`sbx create` default to **direct mode** (host filesystem passed through). This template always passes `--clone` instead, because direct mode breaks in ways that matter here:

- `.venv` would be shared with the host, so the sandbox's own `uv sync` overwrites the host's `.venv` with Linux builds — and `.pre-commit-config.yaml`'s hooks are `language: system`, calling the host's `uv run ruff`/`pyright`, so a host-native `.venv` is required for committing from the host. The two can't coexist.
- virtiofs reports a symlink's `st_size` as 0, so git sees every symlink as "contents disappeared" — committing that unnoticed replaces the link with a broken, empty file.
- `.venv` I/O over virtiofs is slow.

In clone mode the workspace is an independent git clone inside the VM (not a worktree), so none of the above can occur structurally.

**Operational differences from direct mode:**

- Uncommitted and gitignored changes are not in the clone — commit first before recreating a sandbox. In practice the main loss is `.claude/settings.local.json` (permission allowlist), so prompts come back; `.devcontainer/host-*` is Dev Container-only and irrelevant here.
- You collect results by pushing — `git push` works through the proxy's header injection, fitting this template's "unattended run → review as a PR" flow.
- To pull work back without pushing: `git fetch sandbox-<name>` (only while the sandbox is running).
- To bring host commits made *after* sandbox creation into the VM (since `origin` won't have the host's unpushed commits): `git fetch /run/sandbox/source` then `git log HEAD..FETCH_HEAD`.
- `sbx rm` destroys unpushed commits — have the agent push frequently on long runs (the kit's `agentInstructions` says so too).

## Mounting other host folders

Equivalent of the Dev Container's bind mounts. Add paths as positional arguments — the first is the primary (cloned) workspace, any others are additional mounts, always **direct** (not cloned), appearing at the host's absolute path inside the VM:

```bash
sbx create --name claude-auto-<dir> --clone --kit ./.sandbox/kit \
  claude . ~/develop/other-repo:ro ~/docs/design-notes:ro
```

Always use `:ro` for reference material — without it, direct-mode's virtiofs symlink bug and immediate host writes both apply. Don't mount folders containing a platform-specific `.venv`/`node_modules`. Workspaces can only be added at creation time; adding one later means `sbx rm` and recreate.

Mechanism by goal:

- Let the agent read another host folder → additional workspace `<path>:ro`
- Move a one-off file in/out → `sbx cp ./config.json <sandbox>:/home/agent/` (works both directions)
- The host's latest commits for *this* repo → `/run/sandbox/source` (read-only; see clone-mode section above)
- Scratch space inside the VM → the kit's `volumes:` (VM-internal, not a host bind mount)

## What sbx inherits automatically

Measured inside the VM of a claude template — sbx does some of what the Dev Container's `initialize.sh` handles, out of the box:

- **git identity** — `user.name`/`user.email` already hold the host's values.
- **Global gitignore** — placed as `core.excludesFile` = `/home/agent/.gitignore_global`.
- **`~/.claude/skills`** — a read-write virtiofs bind mount from the host; your host skills are shared, and anything the agent changes is reflected back.
- The host's `~/.claude/settings.json` is **not** inherited — write host-specific settings via the kit's `setup.files` or `sbx cp`.

## Task secrets: sbx vs. pass-cli

The Dev Container's pass-cli approach is deliberately not carried into sbx. Instead: `sbx secret set <service> --sandbox <name> -t "<value>"`, plus a `credentials` entry in the kit — the proxy injects the header only for requests to the domains listed. Kit changes need a sandbox recreate; secret changes apply immediately, even while running.

| | pass-cli (Dev Container) | sbx credential injection |
|---|---|---|
| Where the value lives | Inside the container (PAT file + session) | Host only — the real value never enters the VM |
| Injection granularity | Per-command env vars (`pass-cli run`) | Domain-restricted HTTP headers |
| If compromised | Container compromise = PAT compromise (bounded by vault scope) | VM compromise doesn't leak the value (only abuse toward allowed domains) |
| Revocation | Revoke on the Proton side | Replace with `sbx secret` + revoke at the issuer |
| Scope | Per-project vault | Per sandbox (never global `-g`) |

If a tool genuinely needs the real secret as an env var (header injection can't cover it), decide case by case — the value then enters the VM.

## Orchestration (delegating to Codex)

A sandbox is created from one template image (one parent agent), but the kit co-installs the delegation target, so a claude sandbox doubles as an orchestration environment with Claude Code as the parent — same Codex-plugin arrangement as the Dev Container's `post-create.sh`. The Codex config seed (`approval_policy = "on-request"`, auto-review) means a delegated run doesn't stall waiting for approval. Delegate authentication is either an interactive login inside the sandbox, or proxy injection (`sbx secret set openai --sandbox <name>`). Sandboxes can't collaborate with each other (isolated filesystem/network, separate clones in clone mode) — hand-off goes through GitHub push/fetch, so keep tightly-coupled orchestration inside a single sandbox.

## Related

- [.sandbox/README.md](/.sandbox/README.md) — setup steps
- [devcontainer-agent-runtime.md](/docs/knowledge/architecture/devcontainer-agent-runtime.md)
- [sbx-setup-and-yolo-override.md](/docs/knowledge/runbooks/sbx-setup-and-yolo-override.md)
- [sbx-known-and-unverified.md](/docs/knowledge/research/sbx-known-and-unverified.md)
- [ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md)
