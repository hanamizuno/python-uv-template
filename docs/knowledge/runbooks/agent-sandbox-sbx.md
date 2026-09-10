---
type: Runbook
title: Agent sandbox (sbx) — operation and mechanics
description: How the sbx microVM sandbox works, overriding the YOLO defaults, clone mode, secrets, and auth troubleshooting
tags: [sbx, agents, security]
timestamp: 2026-09-06T00:00:00Z
---

# Agent sandbox (sbx) — operation and mechanics

Setup steps are in [`.sandbox/README.md`](/.sandbox/README.md). This document is the reference behind them. Verification status: [sbx-verification.md](/docs/knowledge/research/sbx-verification.md). Why it coexists with the Dev Container: [ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md).

## What sbx adds over the Dev Container

The Dev Container ([devcontainer-agent-runtime.md](/docs/knowledge/architecture/devcontainer-agent-runtime.md)) is a Linux container: no separate kernel, no granular network allow/deny, no nested Docker. sbx closes those gaps:

- **microVM boundary** — a separate kernel, so container-escape kernel bugs are contained.
- **Deny-by-default networking** — outbound TCP only to allowlisted domains (UDP/ICMP blocked).
- **Credentials stay out of the VM** — the host-side proxy injects API keys/tokens into HTTP headers; real values never enter the VM.
- **A Docker daemon per sandbox** — the agent can build/run containers without touching the host's Docker.

Use the Dev Container for interactive human development in VS Code, and sbx for unattended agent runs or anything needing strong isolation.

What the kit ([kit/spec.yaml](/.sandbox/kit/spec.yaml)) installs at creation: `uv` (if missing), Python 3.14 via `uv python install` (matching `.python-version`), `prek`, the Codex CLI plus its Claude Code plugin registration, an initial Codex config seed, and the network-allowlist/credential wiring. `uv sync` and `prek install` are left to the agent (via `agentInstructions`) since an install step's cwd isn't necessarily the workspace.

## Overriding the built-in YOLO launch commands

Both templates default to bypassing all permissions (`claude --dangerously-skip-permissions`, `codex --dangerously-bypass-approvals-and-sandbox`). Passing flags via `sbx run ... --` does **not** help — flag-leading arguments are appended *after* the defaults, so the bypass survives. Two ways to actually replace them:

### Approach A: `sbx create` + `sbx exec` — keeps subscription auth

This is what `.sandbox/README.md` documents. Creating and launching are separate, so the default YOLO entrypoint is never used and the agent type stays the built-in `claude`/`codex`:

```bash
sbx create --clone --kit ./.sandbox/kit claude .
sbx exec -it -w "$PWD" claude-<dir> claude --permission-mode auto

sbx create --clone --kit ./.sandbox/kit codex .
sbx exec -it -w "$PWD" codex-<dir> codex --approve-for-me
```

Proxy-managed OAuth keeps working — credential injection isn't tied to "the first process launched," so the boundary holds for a process started with `sbx exec` in the same sandbox. Caveat: **reconnect with `sbx exec`, never `sbx run`**, which would start the YOLO entrypoint. This combination isn't published as a complete recipe in the official docs — it's this template's own inference, verified on hardware for the sibling pnpm template.

### Approach B: fork kits — requires API-key billing

`sandbox.entrypoint`/`sandbox.command` can only appear in a `kind: sandbox` kit (a mixin can't carry a `sandbox:` block), so thin fork kits sit alongside the shared mixin: [claude-auto/spec.yaml](/.sandbox/claude-auto/spec.yaml), [codex-approve/spec.yaml](/.sandbox/codex-approve/spec.yaml).

```bash
sbx run claude-auto   --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto
sbx run codex-approve --clone --kit ./.sandbox/kit --kit ./.sandbox/codex-approve
```

A fork kit inherits image, credentials, network allowances, volumes, MCP wiring, and agent instructions, overriding only the launch command — but it must declare **both** `entrypoint` and `command`: the effective command is `entrypoint` + `command`, and which side carries the parent's bypass flag is undocumented, so declaring only `entrypoint` risks silently leaving YOLO in place.

> A kit that `extends` a built-in agent **cannot use proxy-managed OAuth**. Register an API key on the host first (`sbx secret set anthropic` / `openai`). Logging in with `/login` inside the VM stores the real token in the VM, against this template's "real values never enter the VM" policy — use approach A to stay on subscription billing.

Either way, verify inside the VM with `ps -eo args | grep claude` (or `codex`): the replacement command must appear with **no bypass flag left**.

`.claude/settings.json` (`permissions.defaultMode: "auto"`) and the Codex seed here (`approval_policy = "on-request"`, `approvals_reviewer = "auto_review"`) encode the same policy, but launch flags are stronger — under sbx the effective value comes from approach A or B. The config files apply when the launch command isn't involved (Dev Container, host, or Claude delegating to Codex). The seed deliberately differs from `.devcontainer/codex-config.toml` (`approval_policy = "never"`); aligning the two is an open question.

## Clone mode

`--clone` is mandatory in this template. Direct mode (the default) passes the host filesystem through, which breaks here:

- `.venv` would be shared, so the sandbox's `uv sync` overwrites the host's `.venv` with Linux builds — and `.pre-commit-config.yaml`'s hooks are `language: system`, calling the host's `uv run ruff`/`pyright`, so committing from the host needs a host-native `.venv`. The two can't coexist.
- virtiofs reports a symlink's `st_size` as 0, so git sees every symlink as "contents disappeared" — committing that unnoticed replaces the link with a broken, empty file.
- `.venv` I/O over virtiofs is slow.

In clone mode the workspace is an independent git clone inside the VM (not a worktree), so none of this can occur structurally.

Operational differences:

- Uncommitted and gitignored files are not in the clone — commit before recreating a sandbox. The practical loss is `.claude/settings.local.json` (permission allowlist), so prompts come back.
- Results come back by pushing, or via the `sandbox-<sandbox>` git remote — see [`.sandbox/README.md`](/.sandbox/README.md). `git push` works through the proxy's header injection, which fits the "unattended run → review as a PR" flow.
- To bring host commits made *after* creation into the VM (since `origin` lacks the host's unpushed commits): `git fetch /run/sandbox/source` then `git log HEAD..FETCH_HEAD`.
- `sbx rm` destroys unpushed commits — have the agent push frequently on long runs (`agentInstructions` says so too).

## Mounting other host folders

Paths are positional arguments; the first is the primary (cloned) workspace, any others are additional mounts — always **direct**, appearing at the host's absolute path inside the VM, and addable only at creation time:

```bash
sbx create --clone --kit ./.sandbox/kit claude . ~/develop/other-repo:ro ~/docs/design-notes:ro
```

Always use `:ro` for reference material — without it, the virtiofs symlink bug and immediate host writes both apply. Don't mount folders holding a platform-specific `.venv`/`node_modules`.

By goal:

- Read another host folder → additional workspace `<path>:ro`
- Move a one-off file in/out → `sbx cp ./config.json <sandbox>:/home/agent/` (both directions)
- The host's latest commits for *this* repo → `/run/sandbox/source` (read-only)
- Scratch space in the VM → the kit's `volumes:` (VM-internal, not a host bind mount)

## What sbx inherits automatically

Some of what the Dev Container's `initialize.sh` handles comes for free (measured on a claude template):

- **git identity** — `user.name`/`user.email` already hold the host's values.
- **Global gitignore** — placed as `core.excludesFile` = `/home/agent/.gitignore_global`.
- **`~/.claude/skills`** — a read-write virtiofs bind mount from the host, so agent changes are reflected back on the host.
- The host's `~/.claude/settings.json` is **not** inherited — use the kit's `setup.files` or `sbx cp` for host-specific settings.

## Task secrets and the network policy

pass-cli is deliberately not carried over. Use `sbx secret set <service> --sandbox <name>` plus a `credentials` entry in the kit; the proxy injects the header only for the domains listed. Kit changes need a recreate; secret changes apply immediately, even while running. A sandbox-scoped secret does **not** survive `sbx rm` (measured) — it goes with the sandbox, so re-register it after every recreate, the ones you do to pick up a kit change included. **Never use the global `-g` form** — it would spill into sandboxes for other repositories.

| | pass-cli (Dev Container) | sbx credential injection |
|---|---|---|
| Where the value lives | Inside the container (PAT file + session) | Host only — never enters the VM |
| Injection granularity | Per-command env vars | Domain-restricted HTTP headers |
| If compromised | Container compromise = PAT compromise | VM compromise doesn't leak the value |
| Scope | Per-project vault | Per sandbox |

If a tool genuinely needs the real secret as an env var, decide case by case — the value then enters the VM.

Audit the allowlist with `sbx policy ls`; the kit's `permissions.network.allow` only *adds* to the default policy, which carries broad wildcards. When probing from inside the VM, judge by the **response body**, not the status code — a denial's body starts with `Blocked by network policy`, while allowed domains return 4xx/404 routinely (`claude.ai` answers 403 with a bot challenge; `api.anthropic.com` answers 404 to `GET /`).

## Orchestration (delegating to Codex)

A sandbox comes from one template image, but the kit co-installs the delegation target, so a claude sandbox doubles as an orchestration environment with Claude Code as the parent — the same arrangement as the Dev Container's `post-create.sh`. The Codex seed (auto-review) means a delegated run doesn't stall waiting for approval. Delegate auth is either an interactive login inside the sandbox or proxy injection (`sbx secret set openai --sandbox <name>`). Sandboxes can't collaborate with each other (isolated filesystem/network, separate clones), so hand-off goes through GitHub — keep tightly-coupled orchestration inside one sandbox.

## Troubleshooting authentication

`sbx ls` is the auth probe — it lists sandboxes cleanly when auth is alive, and surfaces the auth error when not.

For "cannot prompt for password" / "store is locked" / "secret not found" persisting after `sbx login`, `sandboxd` may be holding the auth store's lock, or the auth metadata may be corrupt. Recovery (macOS):

```bash
pkill sandboxd   # or the PID in sandboxd.pid under ~/.docker/caches/com.docker.sandboxes/
rm -f ~/.docker/caches/com.docker.sandboxes/sandboxes/.posixage.lock
rm -f ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/.posixage.lock
rm -rf ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/ZG9ja2VyL2F1dGgvbWV0YWRhdGEvaHViL2RlZmF1bHQ=/
sbx ls && sbx login
```

Delete only the `-auth` side, never the sandbox data itself.

**`git push` fails with `Permission denied (publickey)`:** the clone inherits the host's remote URLs, and no SSH key is carried into the VM, so an `origin` of `git@github.com:<org>/<repo>.git` cannot authenticate. Proxy credential injection is HTTPS-only — the kit's `credentials` entry adds an `Authorization` header for `github.com`/`api.github.com`, which an SSH connection never sees. Push over HTTPS instead (measured 2026-09-10 on the claude template: the HTTPS push succeeds with no secret inside the VM):

```bash
git push https://github.com/<org>/<repo>.git <branch>
git remote set-url origin https://github.com/<org>/<repo>.git   # or fix it for the session
```

`git fetch origin` uses the same SSH URL, so remote-tracking refs also go stale after such a push and the branch keeps reporting "ahead 1". Refresh with an explicit refspec if you leave `origin` on SSH:

```bash
git fetch https://github.com/<org>/<repo>.git 'refs/heads/<branch>:refs/remotes/origin/<branch>'
```

**SSH / headless sessions:** credentials live in the OS keychain, which stays locked with no way to prompt, so `sbx login` fails ([docker/sbx-releases#180](https://github.com/docker/sbx-releases/issues/180) / [#186](https://github.com/docker/sbx-releases/issues/186)). Over SSH to macOS, run `security unlock-keychain ~/Library/Keychains/login.keychain-db` in the same shell first, or do `sbx login` once from a local GUI session. On headless Linux, run a session D-Bus plus `gnome-keyring-daemon --components=secrets` with `DBUS_SESSION_BUS_ADDRESS` inherited by both `sbx` and the daemon. sbx changes auth handling often — update before digging in.

## First-run checklist

The in-VM half of this list has been run ([sbx-verification.md](/docs/knowledge/research/sbx-verification.md)); steps 1 and 3 are host-side and still open. When trying it:

1. `sbx version`, `sbx login`, `sbx kit validate ./.sandbox/kit` (and both fork kits — this also resolves `extends:`).
2. Create and launch per approach A; confirm subscription auth needs no re-login, `git remote -v` / `ls /run/sandbox/source` show clone mode, and `ps -eo args` shows no bypass flag.
3. `sbx secret set github --sandbox <name>` → `sbx secret ls` shows sandbox scope, not global.
4. In the VM: `uv --version`, `uv python list` shows 3.14, `command -v codex`, `~/.local/bin/prek --version`, and `cat ~/.codex/config.toml` shows `${WORKDIR}` expanded.
5. `uv sync --frozen && uv run task lint && uv run task test_cov` passes.
6. `gh api user` succeeds while `echo "$GH_TOKEN"` shows a sentinel; `git ls-remote` and `git push --dry-run` work.
7. Audit `sbx policy ls`; a `curl` outside the allowlist is denied. Watch especially whether uv's managed-CPython download (`astral.sh` → GitHub release assets) got through.
8. Repeat step 2 for Codex (`codex --approve-for-me`), and check whether ChatGPT subscription auth survives.
9. `command -v pass-cli` is empty — confirms the environment detection in `agentInstructions` and `AGENTS.md`.
10. Leave and re-enter → reconnects without re-running install (via `sbx exec`); `sbx rm` and recreate → install runs.
11. Commit in the VM and `git push`; also pull it back with `git fetch sandbox-<name>`.
