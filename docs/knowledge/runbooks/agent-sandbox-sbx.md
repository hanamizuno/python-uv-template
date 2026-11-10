---
type: Runbook
title: Agent sandbox (sbx) — operation and mechanics
description: How the sbx microVM sandbox works, kit spec v3 and environment files, overriding the YOLO defaults, clone mode, secrets, and auth troubleshooting
tags: [sbx, agents, security]
timestamp: 2026-11-09T00:00:00Z
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

What the kit ([kit/spec.yaml](/.sandbox/kit/spec.yaml)) installs at creation: the official `uv` build (when the image's own `uv` can't run — see [Kit spec v3](#kit-spec-v3)), Python 3.14 via `uv python install` (matching `.python-version`), `prek`, Node (only if the image lacks npm) plus the Codex CLI and its Claude Code plugin registration, an initial Codex config seed, and the network-allowlist/credential wiring. `uv sync` and `prek install` are left to the agent (via the kit's agent context) since an install hook's cwd isn't necessarily the workspace.

## Environment files

Each launch is described by an [environment file](https://docs.docker.com/ai/sandboxes/configuration/environment-files/) (`sbxenv.yaml`, sbx v0.51.0+, experimental) that pins the agent, the shared kit (`../kit`), the workspace (`../..` = the repository root, resolved from the file's directory) with `clone: true`, and the launch command:

| File | Agent | Launch |
|---|---|---|
| [claude-auto/sbxenv.yaml](/.sandbox/claude-auto/sbxenv.yaml) | `claude` | `claude --permission-mode auto` |
| [codex-approve/sbxenv.yaml](/.sandbox/codex-approve/sbxenv.yaml) | `codex` | `codex --approve-for-me` |
| [host-claude/sbxenv.yaml](/.sandbox/host-claude/sbxenv.yaml) | overlay | adds `--settings` and a postCreate copy (see [below](#what-sbx-inherits-automatically)) |

The files set no `name:`, so the sandbox is `<agent>-<workspace basename>` (e.g. `claude-python-uv-template`) — each project generated from this template gets its own. `--name` overrides it, and then every `sbx env` command for that sandbox needs the same `--name`.

| Command | What it does |
|---|---|
| `sbx env plan <dir>` | Prints what applying the file would set up (sandbox, kit, git remote, launch, host commands) without applying it |
| `sbx env run <dir>` | Creates the sandbox if missing (running the kit's install hooks), then attaches with the file's launch command. On an existing sandbox it only starts and re-attaches |
| `sbx env create <dir>` | Creates without attaching |
| `sbx env exec <dir> -- <cmd>` | Runs a command in the sandbox — **without** the launch override |
| `sbx env rm <dir>` | Removes the sandbox, the secrets scoped to it, and its `sandbox-<name>` git remote |

Passing several paths deep-merges them in order (later files win; `entrypoint`/`cmd` arrays are replaced, not concatenated) — that is how the `host-claude` overlay layers on top. Changes to kits, workspaces, and secrets declared in the file apply only at creation (`sbx env rm` + run); `entrypoint`/`cmd` apply on every run. Applying a file asks for approval once per change (`--force` skips the prompt).

## Overriding the built-in YOLO launch commands

The built-in agent kits (`docker.io/sbx/<agent>:latest`; check with `sbx kit inspect docker.io/sbx/claude:latest` → "Run Options") default to bypassing all permissions: `claude --dangerously-skip-permissions`, `codex --dangerously-bypass-approvals-and-sandbox`. Passing flags via `sbx run claude -- <args>` does **not** help — arguments are appended *after* the defaults, so the bypass survives. In kit spec v3 a mixin cannot change the workload's launch command and there is no fork (`extends`), so the override lives in the environment file:

```yaml
entrypoint: [claude]
cmd: [--permission-mode, auto]
```

- **Both** `entrypoint` and `cmd` are declared so nothing of the built-in default (the bypass flag) is inherited — an omitted field inherits the default.
- Arguments after `--` replace `cmd`: `sbx env run ./.sandbox/claude-auto -- --permission-mode auto --continue`. Leaving the permission flag out of that list drops it.
- The override applies only to `sbx env run`. `sbx run`, `sbx env exec`, and `sbx exec` start or run under the default YOLO launcher, so **reconnect with `sbx env run` too**.
- Subscription auth keeps working: the built-in kit's proxy-managed OAuth is untouched (the environment file selects the built-in agent, it doesn't replace it).

Verify inside the VM with `ps -eo args | grep -E '^(claude|codex)'`: the replacement command must appear with **no bypass flag left**.

`.claude/settings.json` (`permissions.defaultMode: "auto"`) and the kit's Codex seed (`approval_policy = "on-request"`, `approvals_reviewer = "auto_review"`) encode the same policy, but launch flags are stronger. The built-in claude kit also writes `"defaultMode": "bypassPermissions"` into the VM's `~/.claude/settings.json`, so don't rely on config files — always state the mode as a launch flag. In a **codex** sandbox the built-in kit seeds its own `~/.codex/config.toml` (`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`), so the kit's seed is skipped and `--approve-for-me` (which forces workspace-write + auto-review) is the only guard; a bare `codex` started some other way inside that sandbox runs YOLO. The kit's seed deliberately differs from `.devcontainer/codex-config.toml` (`approval_policy = "never"`); aligning the two is an open question.

> Before v0.51.0 this template used `sbx create` + `sbx exec` (approach A) or fork kits that `extends` the built-in agent (approach B). Fork kits no longer load (`"claude" is no longer a built-in agent`); `sbx create --clone --kit ./.sandbox/kit claude .` + `sbx exec` should still work with the v3 kit (unverified), but the environment file replaces it — it also pins `--clone` and the kit so they can't be forgotten.

## Kit spec v3

sbx v0.51.0 resolves built-in agent names to published v3 kits, and **v1/v2 kits can no longer be combined with them**. [kit/spec.yaml](/.sandbox/kit/spec.yaml) is a v3 mixin (first line `# syntax=docker/sandbox-kit:3`). Mapping from the old v2 fields:

| v2 | v3 |
|---|---|
| `name` | none (identity is the reference); `displayName` / `description` only |
| `setup.install[]` | `com.docker.sandbox/lifecycle@1` → `install[]` |
| `setup.files[]` (`onlyIfMissing`) | `lifecycle@1` → `files[]` (`overwrite: false`). This kit writes the Codex seed from an install hook instead (see below) |
| `${WORKDIR}` | hook `env: [WORKSPACE_DIR]` |
| static `files/` directory | none — copy per-user files with `sbx cp` (the `host-claude` overlay does this) |
| `permissions.network.allow` | `com.docker.sandbox/network-policy@1` → `install.allow` / `runtime.allow` |
| `credentials[]` | `com.docker.sandbox/credential@1` (`phase: runtime`, `optional: true`) |
| `agentInstructions` | `com.docker.sandbox/agent-context@2` (lands in `~/.claude/kits-agent-context/kit.md`) |

What behaves differently in v3:

- **The install phase has its own network allowlist.** `install.allow` is open only while install hooks run and closes before the agent starts. When a hook gains a download source, add it to `install.allow` too.
- **Hook environments are deny-by-default.** Only basics (`PATH`, `HOME`, …) and proxy/certificate settings pass through; anything else is listed in the hook's `env`.
- **`${{ kit.env.WORKSPACE_DIR }}` in `lifecycle.files` fails to expand on the built-in claude kit** (its final environment has no `WORKSPACE_DIR`), which is why the Codex seed is written by a hook.
- **The base image is Docker Hardened Images (Debian 13) on 16K memory pages.** Its packaged `/usr/bin/uv` aborts with `<jemalloc>: Unsupported system page size`; the kit installs the official astral build into `/usr/local/bin` (ahead of `/usr/bin` on the agent's PATH, but not on root hooks' PATH — hence the absolute path in the hook). `~/.local/bin` is already on PATH, and the image ships no Node.
- **A descriptor-only mixin needs no build step** — the local directory is used as is. Validate with `sbx kit validate ./.sandbox/kit` (through sandboxd; `--offline` can't handle v3 source kits).
- **The built-in opencode kit still uses `agent-context@1`**, which can't compose with this kit's `@2`.
- Sandboxes created before v0.51.0 stay on the v2 setup; remove and recreate them.

## Clone mode

`clone: true` is mandatory in this template (the environment files set it; `--clone=false` would override it — don't). Direct mode passes the host filesystem through, which breaks here:

- `.venv` would be shared, so the sandbox's `uv sync` overwrites the host's `.venv` with Linux builds — and `.pre-commit-config.yaml`'s hooks are `language: system`, calling the host's `uv run ruff`/`pyright`, so committing from the host needs a host-native `.venv`. The two can't coexist.
- virtiofs reports a symlink's `st_size` as 0, so git sees every symlink as "contents disappeared" — committing that unnoticed replaces the link with a broken, empty file.
- `.venv` I/O over virtiofs is slow.

In clone mode the workspace is an independent git clone inside the VM (not a worktree), so none of this can occur structurally.

Operational differences:

- Uncommitted and gitignored files are not in the clone — commit before recreating a sandbox. The practical loss is `.claude/settings.local.json` (permission allowlist), so prompts come back.
- Results come back by pushing, or via the `sandbox-<sandbox>` git remote — see [`.sandbox/README.md`](/.sandbox/README.md). `git push` works through the proxy's header injection, which fits the "unattended run → review as a PR" flow.
- To bring host commits made *after* creation into the VM (since `origin` lacks the host's unpushed commits): `git fetch /run/sandbox/source` then `git log HEAD..FETCH_HEAD`.
- `sbx env rm` destroys unpushed commits — have the agent push frequently on long runs (the kit's agent context says so too).

## Mounting other host folders

Additional host folders are declared in the environment file — always **direct** mounts (not cloned), and only applied at creation. Keep personal paths out of the committed files: put them in a local overlay (e.g. a gitignored `.sandbox/local.yaml`) and pass it after the base file:

```yaml
# .sandbox/local.yaml — sbx env run ./.sandbox/claude-auto ./.sandbox/local.yaml
schemaVersion: "1"
additionalWorkspaces:
  - path: /Users/me/develop/other-repo   # absolute: `~` is not expanded, and relative
    readOnly: true                       # paths resolve from this file's directory
```

Always use `readOnly: true` for reference material — without it, the virtiofs symlink bug and immediate host writes both apply. Don't mount folders holding a platform-specific `.venv`/`node_modules`. The mount appears at the host's absolute path inside the VM.

By goal:

- Read another host folder → `additionalWorkspaces` with `readOnly: true`
- Move a one-off file in/out → `sbx cp ./config.json <sandbox>:/home/agent/` (both directions)
- The host's latest commits for *this* repo → `/run/sandbox/source` (read-only)

## What sbx inherits automatically

Less of what the Dev Container's `initialize.sh` handles comes for free than before v3 (measured on the v0.51.0 claude kit):

- **git identity is not inherited.** `user.name`/`user.email` are unset in the VM (v2 copied the host's), so set them once inside the sandbox (`git config --global user.name …`) before the agent commits. A global gitignore is still wired up (`core.excludesFile`).
- **`~/.claude/skills`** — a **read-only** virtiofs mount of the host's skills (v2 mounted it read-write). `sandboxOptions.skills` in an environment file can set `readwrite` or `off`.
- The host's `~/.claude/settings.json` is **not** inherited. Don't write or merge into the VM's `~/.claude/settings.json` either: the built-in kit writes it at creation (including `"defaultMode": "bypassPermissions"`) and may replace kit content there. Instead, the opt-in [`host-claude` overlay](/.sandbox/host-claude/sbxenv.yaml) runs [`.sandbox/stage-host-claude.sh`](/.sandbox/stage-host-claude.sh) on the host after creation (a `lifecycle.postCreate` command), which `sbx cp`s the host settings (host-home paths rewritten) to `~/.claude/host-settings.json` plus `statusline-command.sh`, and the overlay's `cmd` adds `--settings /home/agent/.claude/host-settings.json`. Note that `--settings` outranks the project's `.claude/settings.json`, unlike the Dev Container's merge into user settings; the `--permission-mode` flag still wins over either. The copies are owned by the host's uid (world-readable), which is enough for Claude Code to read them.

## Task secrets and the network policy

pass-cli is deliberately not carried over. Use `sbx secret set <service> --sandbox <name>` plus a `credential@1` entry in the kit; the proxy injects the header only for the domains listed. Kit changes need a recreate; a secret registered after creation applies immediately, even while running (measured on v0.51.0). A sandbox-scoped secret does **not** survive `sbx env rm` — it goes with the sandbox, so re-register it after every recreate, the ones you do to pick up a kit change included. **Never use the global `-g` form** — it would spill into sandboxes for other repositories.

| | pass-cli (Dev Container) | sbx credential injection |
|---|---|---|
| Where the value lives | Inside the container (PAT file + session) | Host only — never enters the VM |
| Injection granularity | Per-command env vars | Domain-restricted HTTP headers |
| If compromised | Container compromise = PAT compromise | VM compromise doesn't leak the value |
| Scope | Per-project vault | Per sandbox |

Avoid `-t <token>` (it lands in shell history): omit it to be prompted, or use `--ref op://<vault>/<item>/<field>` / `--command '<prints the token>'`. If a tool genuinely needs the real secret as an env var, decide case by case — the value then enters the VM.

Audit the allowlist with `sbx policy ls`; the kit's `runtime.allow` only *adds* to the default policy, which carries broad wildcards. When probing from inside the VM, judge by the **response body**, not the status code — a denial is a 403 whose body reads `Approval required for <host>:<port>.`, while allowed domains return 4xx/404 routinely (`api.anthropic.com` answers 404 to `GET /`).

## Orchestration (delegating to Codex)

A sandbox comes from one agent kit, but the shared kit co-installs the delegation target, so a claude sandbox doubles as an orchestration environment with Claude Code as the parent — the same arrangement as the Dev Container's `post-create.sh`. The Codex seed (auto-review) means a delegated run doesn't stall waiting for approval. Delegate auth is either an interactive login inside the sandbox or proxy injection (`sbx secret set openai --sandbox <name>`). Sandboxes can't collaborate with each other (isolated filesystem/network, separate clones), so hand-off goes through GitHub — keep tightly-coupled orchestration inside one sandbox.

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

**`git push` fails with `Permission denied (publickey)`:** the clone inherits the host's remote URLs, and no SSH key is carried into the VM, so an `origin` of `git@github.com:<org>/<repo>.git` cannot authenticate. Proxy credential injection is HTTPS-only — the kit's credential entry adds an `Authorization` header for `github.com`/`api.github.com`, which an SSH connection never sees. Push over HTTPS instead:

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

Most of this was run on v0.51.0 ([sbx-verification.md](/docs/knowledge/research/sbx-verification.md)). When trying it on a new machine or sbx version:

1. `sbx version` (v0.51.0+), `sbx login`, `sbx kit validate ./.sandbox/kit`, `sbx env plan ./.sandbox/claude-auto`.
2. `sbx env run ./.sandbox/claude-auto`; confirm subscription auth needs no re-login, `git remote -v` / `ls /run/sandbox/source` show clone mode, and `ps -eo args` shows `claude --permission-mode auto` with no bypass flag.
3. `sbx secret set github --sandbox <name>` → `sbx secret ls` shows the sandbox scope, not global.
4. In the VM: `command -v uv` is `/usr/local/bin/uv` and `uv --version` runs, `uv python list --only-installed` shows 3.14, `command -v codex prek`, and `cat ~/.codex/config.toml` ends with the workspace's `[projects."…"]` entry.
5. `uv sync --frozen && uv run task lint && uv run task test_cov` passes.
6. `gh api user` succeeds while `echo "$GH_TOKEN"` shows a sentinel; `git ls-remote` and `git push --dry-run` work (over HTTPS — see above).
7. Audit `sbx policy ls`; a `curl` outside the allowlist returns `Approval required for …`.
8. Repeat step 2 for Codex (`sbx env run ./.sandbox/codex-approve` → `codex --approve-for-me`), and check whether ChatGPT subscription auth survives.
9. Set the git identity (`git config --global user.name/user.email`); `command -v pass-cli` is empty — confirms the environment detection in the agent context and `AGENTS.md`.
10. Leave and run `sbx env run` again → re-attaches without re-running install; `sbx env rm` and run → install runs.
11. Commit in the VM and `git push`; also pull it back with `git fetch sandbox-<name>`.
