# AI Agent Sandbox (Docker Sandboxes / sbx)

Configuration for running AI coding agents inside a microVM with
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`). It
**coexists** with the current [Dev Container](../.devcontainer/README.md) — it
does not replace it. The intent is a staged migration: run both in parallel
first, and only then shrink the agent-related parts of the Dev Container if
nothing is missing.

## Positioning

The Dev Container uses a Linux container as its isolation boundary. As
`.devcontainer/README.md` says under "What this isolation *does not* cover", it
provides no separate kernel, no granular network allow/deny lists, and no
nested Docker. This directory implements the "higher-assurance sandbox" that
same section recommends. What sbx adds:

- **microVM boundary** — a separate kernel, so kernel vulnerabilities that lead
  to container escape are contained.
- **Deny-by-default networking** — outbound TCP only reaches domains on an
  allowlist (UDP / ICMP are blocked).
- **Credentials stay out of the VM** — API keys and tokens are injected into
  HTTP headers by the host-side proxy, so the **real values never enter the
  VM**.
- **A Docker daemon per sandbox** — the agent can build and run containers
  without touching the host's Docker.

Rough guide to which one to use:

| Purpose | Environment |
|---|---|
| Interactive human development, working in VS Code | Dev Container |
| Unattended agent runs, tasks that need strong isolation | sbx |

> **Note:** `sbx` **runs on the host OS**. You cannot use it from inside the
> Dev Container.

## Prerequisites and install

- macOS 14 (Sonoma) or later on Apple Silicon, Windows 11, or Ubuntu 24.04+
  with KVM enabled
- Docker Desktop / Docker Engine are **not required** (`sbx` is a standalone
  microVM runtime and coexists with an existing Docker setup such as Colima)

```bash
brew install docker/tap/sbx   # macOS; see the official docs for other OSes
sbx version

# Sign in to your Docker account (required; opens a browser device-code flow).
# Without it, sbx commands fail with
# "unexpected authentication error: ... cannot prompt the user for password".
# This is sbx's own authentication, separate from `docker login` for Colima etc.
sbx login
```

After signing in you may be asked to choose a default network policy
(Open / Balanced / Locked Down). This template recommends **Locked Down or
Balanced** — the kit adds the domains it needs via `allow`, and you can adjust
later with `sbx policy`.

## Initial setup

The built-in agents' default launch commands are YOLO, so this template
overrides them. The steps depend on how you authenticate (see "Overriding the
YOLO defaults" below) — what follows is **approach A**, which keeps
subscription authentication (Claude Max / ChatGPT). If you are happy to be
billed via API keys, approach B (fork kits) is shorter.

```bash
# 1) From this repository's checkout, apply the shared mixin and create the
#    sandbox only. The positional argument is the built-in agent type (claude);
#    the agent is not launched yet. Without --name, the sandbox is named
#    `<agent>-<dir>`. Approve the kit's credentials prompt that appears at
#    creation time (answering No disables proxy injection).
#    --clone is mandatory — see "Running in clone mode" below.
cd <this repository's checkout>
sbx create --name claude-auto-<dir> --clone --kit ./.sandbox/kit claude .

# 2) Launch with the permission mode you want. Always enter this way — using
#    `sbx run` would start the default YOLO entrypoint instead.
sbx exec -it -w "$PWD" claude-auto-<dir> claude --permission-mode auto

# 3) Register a GitHub fine-grained PAT scoped to that sandbox alone.
#    (`github` matches the service name in the kit's credentials. Pass the
#     sandbox name to --sandbox; `sbx ls` shows it. Sandbox-scoped secrets take
#     effect immediately, even on a running sandbox. The scoping policy is the
#     same as .devcontainer/README.md "Restricting GitHub permissions (PAT)" —
#     a repository-scoped PAT goes only to that repository's sandbox. The value
#     never enters the VM; the proxy injects it into GitHub-bound headers only.)
sbx secret set github --sandbox claude-auto-<dir> -t "<fine-grained PAT>"

# Codex works the same way.
sbx create --name codex-approve-<dir> --clone --kit ./.sandbox/kit codex .
sbx exec -it -w "$PWD" codex-approve-<dir> codex --approve-for-me
```

Use `--name` explicitly only when you want several sandboxes for the same
workspace and agent in parallel.

> **Do not use `-g` (global):** `sbx secret set -g github` registers the secret
> for your whole user account, so it **can be injected into every sandbox you
> create afterwards, including ones for other repositories**. Built-in services
> such as `github` are auto-injected by provenance even without a kit
> declaration, so a global registration works against this template's policy of
> separating permissions per repository. Register with sandbox scope instead
> (a sandbox-scoped value wins over a global one). Note that the argument form
> of `sbx secret set` differs between CLI versions. This README uses the
> current `sbx secret set <service> --sandbox <sandbox name> [-t <token>]`
> form; some environments still take the older
> `sbx secret set <sandbox name> <service>`. If they disagree, check
> `sbx secret set --help`.

The first run needs per-agent authentication (a browser login for Claude, and
so on). State inside the sandbox, authentication included, persists until you
`sbx rm` it.

What the kit ([kit/spec.yaml](kit/spec.yaml)) sets up at sandbox creation:

- `uv` (installed only if the sandbox template does not already ship it)
- The Python 3.14 toolchain via `uv python install`, matching
  `../.python-version`
- `prek` (the pre-commit hook runner) via `uv tool install`, plus a
  `/etc/profile.d` entry putting `~/.local/bin` on PATH
- The Codex CLI, plus registration of the Codex plugin for Claude Code (see
  "Orchestration" below; a no-op in sandboxes without `claude`)
- An initial Codex config seed (`~/.codex/config.toml`; not overwritten if one
  already exists)
- Network allowlist additions and GitHub PAT header injection

`uv sync` and `prek install` are **not** run by the kit: the cwd of an install
step is not necessarily the workspace. They are handled by the agent instead,
via the kit's `agentInstructions`.

## Overriding the YOLO defaults

The built-in sbx agents **default to YOLO launch commands**:

| Agent | Default sbx launch command |
|---|---|
| `claude` | `claude --dangerously-skip-permissions` |
| `codex` | `codex --dangerously-bypass-approvals-and-sandbox` |

A microVM is a real isolation boundary, but that is no reason to leave
workspace destruction or network-side actions unrestricted, so this template
replaces the defaults with:

| Agent | After replacement | Meaning |
|---|---|---|
| `claude-auto` | `claude --permission-mode auto` | The model judges permissions, but nothing is bypassed |
| `codex-approve` | `codex --approve-for-me` | Keeps workspace-write; escalated approval requests go to automatic review |

**You cannot override this by passing arguments through with `--`.** Arguments
passed as `sbx run claude -- --permission-mode auto` are **appended after the
default flags** when they start with a flag, so
`--dangerously-skip-permissions` survives. There are two ways to replace them,
and **which one you pick depends on how you authenticate**.

### Approach A: `sbx create` + `sbx exec` (to keep subscription auth)

Separate creating the sandbox from launching the agent. `sbx create` only
creates the sandbox and does not launch the agent, so you never hit the default
YOLO entrypoint and the agent type stays the **built-in `claude` / `codex`**:

```bash
# 1) Create the sandbox only, with the built-in agent type (shared mixin only)
sbx create --name claude-auto-<dir> --clone --kit ./.sandbox/kit claude .

# 2) Launch directly with the flags you want (-w takes the workspace path;
#    clone mode mirrors the host's absolute path, so $PWD is correct)
sbx exec -it -w "$PWD" claude-auto-<dir> claude --permission-mode auto
```

```bash
sbx create --name codex-approve-<dir> --clone --kit ./.sandbox/kit codex .
sbx exec -it -w "$PWD" codex-approve-<dir> codex --approve-for-me
```

**The advantage of this approach is that the built-in agents' proxy-managed
OAuth keeps working.** Credential injection is not tied to "the first process
launched" — the host-side proxy intercepts traffic leaving the sandbox — so the
boundary still holds for a separate process started with `sbx exec` in the same
sandbox.

Caveats:

- **Reconnecting with `sbx run` starts the default YOLO entrypoint.** Always
  re-enter via the `sbx exec` form.
- **Omitting `--name` names the sandbox `claude-<dir>`** (no `claude-auto-`
  prefix). The examples here assume an explicit `--name`; if you omit it,
  substitute the real name (from `sbx ls`, or `$SANDBOX_NAME` inside the VM)
  wherever `sbx secret set --sandbox` / `git fetch sandbox-...` appear.
- **This combination is not published as a complete recipe in the official
  docs.** `sbx create` / `sbx exec` are supported commands, but "create a
  built-in sandbox, exec the same agent binary with different flags, and keep
  OAuth" is this template's own inference. It was verified on hardware for the
  pnpm sibling template with the claude template + a Claude Max subscription
  (see "Known and unverified items").

### Approach B: fork kits (when API-key billing is acceptable)

`sandbox.entrypoint` / `sandbox.command` can only appear in a `kind: sandbox`
kit — a mixin kit cannot carry a `sandbox:` block. So alongside the shared
mixin ([kit/spec.yaml](kit/spec.yaml)) there are thin fork kits that do nothing
but `extends` the built-in agents:

- [claude-auto/spec.yaml](claude-auto/spec.yaml) — `extends: claude`
- [codex-approve/spec.yaml](codex-approve/spec.yaml) — `extends: codex`

`--kit` can be given more than once, and the positional argument to `sbx run`
is the fork kit's `name:`:

```bash
sbx run claude-auto   --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto
sbx run codex-approve --clone --kit ./.sandbox/kit --kit ./.sandbox/codex-approve
```

A fork kit inherits the image, credentials, network allowances, volumes, MCP
wiring, and agent instructions from its parent, overriding only the launch
command. In doing so it **declares both `entrypoint` and `command`
explicitly** — the effective command is `entrypoint` + `command`
(`command.interactive` on a TTY, `command.default` otherwise), and it is not
documented which of the two carries the parent's bypass flag. Replacing only
the `entrypoint` would produce
`claude --permission-mode auto --dangerously-skip-permissions` if the parent's
flag lives on the `command` side — **leaving YOLO in place unnoticed** (a
silent failure). Declaring both inherits nothing and fails safe either way.

> **Authentication constraint:** a kit that `extends` a built-in agent
> **cannot use the proxy-managed OAuth**. Register an API key on the host
> before the first launch (`sbx secret set anthropic` /
> `sbx secret set openai`). Using `/login` (OAuth) inside the VM **stores the
> real token inside the VM**, which departs from this template's "real values
> never enter the VM" policy. To stay on subscription billing, use approach A.

### How this relates to the config files

Claude Code's [`../.claude/settings.json`](../.claude/settings.json)
(`permissions.defaultMode: "auto"`) and the Codex `~/.codex/config.toml` seed
(`approval_policy = "on-request"` / `approvals_reviewer = "auto_review"`) are
set to the same policy, but **launch flags are stronger**, so under sbx the
effective value is decided by approach A or B. The config files are what apply
when the launch command is not involved — running in the Dev Container or on
the host, and when Claude delegates to Codex.

Note that the Codex seed here deliberately differs from
`../.devcontainer/codex-config.toml`, which uses `approval_policy = "never"`.
The seed in this kit is the counterpart of the `codex-approve` fork kit's
`--approve-for-me`. Whether to align the Dev Container as well is left as a
separate decision.

## Day-to-day operation

- Running `sbx run` in the same workspace **reconnects to the existing
  sandbox** (install steps are not re-run).
- `sbx ls` lists them, `sbx stop <name>` stops one, `sbx rm <name>` deletes one
  (**all state inside the VM is lost** — in clone mode that includes unpushed
  commits).
- After changing a kit, recreate the sandbox to pick it up: `sbx rm`, then
  `sbx run --clone --kit ...` again. (`sbx kit add` does not accept a kit
  containing `setup.files`, so it cannot be used with this kit.)
- To work in parallel on the same workspace, create a separately named sandbox
  with `--name`.

## Running in clone mode

`sbx run` defaults to **direct mode**, which passes the host filesystem through
so the VM sees the host's absolute paths. **In this template, always pass
`--clone`.** Direct mode has problems that this setup cannot live with:

1. **`.venv` is shared with the host, mixing macOS and Linux binaries.** A
   "never run `uv sync` on the host" rule does not prevent it — the sandbox's
   own `uv sync` **overwrites the host's `.venv` with Linux builds**. The hooks
   in `../.pre-commit-config.yaml` are `language: system` and call the host's
   `uv run ruff` / `uv run pyright`, so committing from the host requires a
   host-native `.venv`. The two cannot coexist.
2. **virtiofs reports a symlink's `st_size` as 0.** git reads symlinks via
   their size, so any symlink in the tree shows up as a "contents disappeared"
   change. **Committing that without noticing records a broken, empty file in
   place of the link.**
3. `.venv` I/O goes through virtiofs, making installs and tests slow.

In clone mode the workspace is an **independent git clone inside the VM** (not
a worktree), so none of these can occur structurally. The host's `.venv` is
left alone and never needs to be touched.

### Operational differences

- **Uncommitted changes are not in the clone.** Commit first if you have work
  in progress when recreating a sandbox.
- **Gitignored files are not in it either.** In practice the only loss is
  `.claude/settings.local.json` (Claude Code's permission allowlist), so
  permission prompts come back. `.devcontainer/host-*` is Dev Container-only
  and irrelevant to sbx.
- **You collect results by pushing.** `git push` to GitHub is known to work
  through the proxy's header injection, so pushing a branch and opening a PR is
  the normal hand-off path. It also fits this template's split of "unattended
  agent run → review as a PR".
- To pull work back to the host without pushing, fetch from the git-daemon the
  sandbox exposes (only while the sandbox is running):

  ```bash
  git fetch sandbox-claude-auto-<dir>
  ```

- In the other direction, to bring **commits added on the host after the
  sandbox was created** into the VM, fetch from the read-only bind mount of the
  host repository (`origin` points at GitHub, so it does not contain the host's
  unpushed commits):

  ```bash
  git fetch /run/sandbox/source
  git log HEAD..FETCH_HEAD --oneline
  ```

- **`sbx rm` destroys unpushed commits.** For long unattended runs, have the
  agent push frequently (the kit's `agentInstructions` says so too).

## Mounting other host folders

This is the equivalent of the Dev Container's bind mounts (`volumes` in
`compose.yaml`) and the staging done by `initialize.sh`. With sbx you **add
paths as positional arguments to `sbx create` / `sbx run`** — the first path is
the primary workspace, and any others are additional mounts:

```bash
sbx create --name claude-auto-<dir> --clone --kit ./.sandbox/kit \
  claude . ~/develop/other-repo:ro ~/docs/design-notes:ro
```

- Additional workspaces are **excluded from `--clone` and always direct
  mounted** (only the first path is cloned).
- Inside the VM they appear at **the host's absolute path**.
- `:ro` makes one read-only. `sbx run` takes the same form.
- **Workspaces can only be added at creation time.** To add one later,
  `sbx rm` and recreate (same as for kit changes).

> **Always use `:ro` for reference material.** The extra mounts are direct
> mounts, so every direct-mode problem listed under "Running in clone mode"
> applies to them. Without `:ro` the agent's writes land on the host
> immediately, punching a hole in the isolation; and because of the virtiofs
> symlink `st_size` = 0 problem, passing a git repository read-write can
> produce commits that destroy symlinks. Do not pass folders containing a
> platform-specific `.venv` or `node_modules`.

Which mechanism to use for what:

| Goal | Mechanism |
|---|---|
| Let the agent read another host folder | Additional workspace `<path>:ro` |
| Move a one-off file in or out | `sbx cp ./config.json <sandbox>:/home/agent/` (works both ways; one side takes the `SANDBOX:PATH` form) |
| The host's latest commits for **this** repository | `/run/sandbox/source` (read-only bind mount; see "Operational differences") |
| Just some scratch space inside the VM | The kit's `volumes:` (**not** a host bind mount — a VM-internal block or tmpfs volume) |

### What sbx inherits automatically

sbx does some of what the Dev Container's `initialize.sh` handles, out of the
box. Measured inside the VM of a claude template:

- **git identity** — `user.name` / `user.email` already hold the host's values
  (no staging needed).
- **Global gitignore** — placed as `core.excludesFile` =
  `/home/agent/.gitignore_global`.
- **`~/.claude/skills`** — a **read-write virtiofs bind mount** from the host
  (visible in `mount | grep virtiofs`). Your host skills are shared, and
  **anything the agent changes is reflected back on the host**.
- The host's `~/.claude/settings.json` is **not** inherited (the VM gets its
  own sbx-managed contents). If you need host-specific settings such as a
  statusline, write them with the kit's `setup.files` or carry them in with
  `sbx cp`.

## Auditing the network policy

Outbound traffic is deny-by-default, but **the default allowlist contains broad
wildcards**. Always check it on first use:

```bash
sbx policy ls
```

The kit's `permissions.network.allow` is an **addition to the default policy**;
it does not trim the default's broad allowances. Narrowing the effective policy
is a host-side `sbx policy` operation. (Because deny wins over allow, you can
also add `permissions.network.deny` to the kit to close specific domains.) The
ideal state is that the kit's allow list alone — PyPI / astral.sh / GitHub /
the npm registry for the agent CLIs / each agent's API / apt repositories — is
enough.

Probing from inside the VM tells you whether a domain is allowed by the
*response body* (a denial is HTTP 403 with a `Blocked by network policy` body):

```bash
curl -s https://example.com/ | head -1
# Blocked by network policy: domain example.com:443
#   detail: no matching allow rule — blocked by default deny policy
```

**Do not judge by HTTP status alone.** Allowed domains return 4xx all the time
(`claude.ai` is allowed but answers 403 with a Cloudflare bot challenge;
`api.anthropic.com` answers 404 to `GET /`). What identifies a denial is
**whether the body starts with `Blocked by network policy`**.

Measurement on the sibling template found that **the default policy does not
allow `console.anthropic.com` or `claude.ai`**, both of which can be needed for
an agent's interactive login (OAuth), so the kit adds them to its allow list.
Telemetry endpoints (`sentry.io` and friends) are best left denied.

## Task secrets

The Dev Container's pass-cli approach is **deliberately not carried over into
this environment**. Use sbx's native mechanism:

```bash
# On the host, scoped to the target sandbox.
# (The name matches the service name in the kit's credentials. Do not use the
#  global -g form: it would spill into sandboxes for other repositories.)
sbx secret set example --sandbox <sandbox name> -t "<API key>"
```

Then add an entry to the kit's `credentials` (a commented-out template lives in
`spec.yaml`), and the host-side proxy will inject the header only for requests
bound for the domains you list. The corresponding environment variable inside
the VM (`apiKey.name`) holds a sentinel value; the real value is only ever
spliced into the header by the proxy just before the request goes out. Kit
changes need the sandbox recreated (`sbx rm`, then `run` again), but
sandbox-scoped secrets themselves apply immediately, even while running.

How it differs from the pass-cli approach:

| | pass-cli (Dev Container) | sbx credential injection |
|---|---|---|
| Where the value lives | Inside the container (PAT file + session) | Host only. **The real value never enters the VM** |
| Injection granularity | Per-command environment variables (`pass-cli run`) | Domain-restricted HTTP headers |
| If compromised | Container compromise = PAT compromise (bounded by vault scope) | VM compromise does not leak the value (only abuse toward allowed domains) |
| Revocation | Revoke on the Proton side | Replace with `sbx secret` + revoke at the issuer |
| Scope | Per-project vault | Per sandbox (never the global `-g` registration) |

If you hit a tool that genuinely needs the real secret as an environment
variable (header injection cannot cover it), decide case by case, understanding
the trade-off that the value then enters the VM.

## Orchestration (multiple agents in one sandbox)

A sandbox is created from one template image (= one parent agent), but the kit
co-installs the delegation target, so a **claude sandbox doubles as an
orchestration environment with Claude Code as the parent**:

- The kit installs the Codex CLI (skipped when the template already ships it)
  and registers Codex as a Claude Code plugin (the codex-rescue subagent and
  the `/codex` skills) — the same arrangement as the Dev Container's
  `post-create.sh`.
- The `~/.codex/config.toml` seed (`approval_policy = "on-request"` /
  `approvals_reviewer = "auto_review"` / `sandbox_mode = "workspace-write"` —
  equivalent to the CLI's `--approve-for-me`) is shared, so a delegated run
  from Claude does not stall waiting for approval. Escalated requests go to
  automatic review rather than to a human.
- Authentication for the delegate is either an interactive login inside the
  sandbox (`codex login`; persists until `sbx rm`) or proxy injection for the
  built-in service (`sbx secret set openai --sandbox <sandbox name>`, keeping
  the real API key out of the VM). ChatGPT subscription authentication means
  interactive login.
- In a sandbox created for running codex on its own, these steps become no-ops
  via their `command -v` guards.

Note that **sandboxes cannot really collaborate with each other** (isolated in
both filesystem and network; in clone mode each has its own clone), so hand-off
goes through GitHub push / fetch. Keep tightly coupled orchestration inside a
single claude sandbox.

## Host trial checklist

Use this to evaluate the setup during the coexistence period. **None of it has
been run for this repository yet** — the items below are adapted from the
sibling pnpm template, where the equivalents passed (see "Known and unverified
items").

1. `sbx version` — installation check
2. `sbx login` — sign in to your Docker account (browser device-code flow)
3. `sbx kit validate ./.sandbox/kit` / `sbx kit validate ./.sandbox/claude-auto`
   / `sbx kit validate ./.sandbox/codex-approve` — kit schema validation,
   including resolution of `extends:`
4. Verify the launch-mode override (branch by approach; trying both and
   comparing is ideal):
   - **Approach A**:
     `sbx create --name claude-auto-<dir> --clone --kit ./.sandbox/kit claude .`
     then
     `sbx exec -it -w "$PWD" claude-auto-<dir> claude --permission-mode auto`.
     The most important check is that it **starts on subscription
     authentication** without asking you to log in again.
   - **Approach B**:
     `sbx run claude-auto --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto`.
     Authentication should demand an API key registration
     (`sbx secret set anthropic`); confirm that behaviour too.
   - For either, check inside the VM that `git remote -v` / `ls /run/sandbox/source`
     show clone mode, and that `ps -eo args | grep claude` shows
     `claude --permission-mode auto` (**with no `--dangerously-skip-permissions`
     left**).
5. `sbx secret set github --sandbox claude-auto-<dir>` → `sbx secret ls` shows
   the scope is per-sandbox, not global
6. Inside the VM: `uv --version` / `uv python list` shows 3.14 /
   `command -v codex` / `~/.local/bin/prek --version`
7. `uv sync --frozen && uv run task lint && uv run task test_cov` passes
8. `cat ~/.codex/config.toml` — `${WORKDIR}` has expanded to the real path
9. `gh api user` succeeds (and `echo "$GH_TOKEN"` shows a sentinel value =
   confirmation that the real value is not in the VM). Also try
   `git ls-remote` and `git push --dry-run`
10. Audit `sbx policy ls`; a `curl` to a domain outside the allowlist is denied
    (body starts with `Blocked by network policy`). Pay particular attention to
    whether uv's managed-CPython download succeeded — that path
    (`astral.sh` → GitHub release assets) is the one most likely to need
    allowlist adjustment
11. Launch Codex the same way as step 4 — `ps -eo args | grep codex` shows
    `codex --approve-for-me`, and check whether ChatGPT subscription
    authentication survives
12. `command -v pass-cli` is empty, confirming that the environment detection in
    `agentInstructions` and `../AGENTS.md` holds
13. Leave and re-enter → it reconnects (install does not re-run). `sbx rm` and
    recreate → install runs. **With approach A, reconnect with `sbx exec`**
    (entering with `sbx run` starts the default YOLO entrypoint)
14. Commit inside the VM and `git push` → it reaches GitHub. It can also be
    pulled from the host with `git fetch sandbox-claude-auto-<dir>`

## Troubleshooting (authentication)

`sbx` has no dedicated equivalent of `gh auth status` in the current docs. In
practice **`sbx ls` is the authentication probe** — if authentication is alive
you get the sandbox list (exiting cleanly even when empty), and if it is broken
the authentication error surfaces directly. It is also worth checking
`sbx --help` for newly added `account` / `logout` subcommands.

If authentication errors such as "cannot prompt the user for password", "store
is locked", or "secret not found" persist even after `sbx login`, there are
reports of the background `sandboxd` daemon holding the auth store's lock, or
of corrupted authentication metadata. Recovery (macOS):

```bash
# 1) Stop sandboxd
pkill sandboxd   # or kill the PID in sandboxd.pid under ~/.docker/caches/com.docker.sandboxes/

# 2) Remove the lock files
rm -f ~/.docker/caches/com.docker.sandboxes/sandboxes/.posixage.lock
rm -f ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/.posixage.lock

# 3) Clear the authentication metadata (the auth side only, not the sandboxes)
rm -rf ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/ZG9ja2VyL2F1dGgvbWV0YWRhdGEvaHViL2RlZmF1bHQ=/

# 4) Restart the daemon with any command and trigger re-authentication
sbx ls
sbx login
```

Be careful not to delete the sandbox data itself (the `com.docker.sandboxes`
side).

**SSH / headless session limitation:** sbx stores credentials in the OS
keychain (Keychain on macOS, Secret Service/D-Bus on Linux). Over SSH or in a
headless session the keychain stays locked and no prompt can be shown, so
`sbx login` fails with "saving credentials: cannot prompt the user for
password" (the same family as
[docker/sbx-releases#180](https://github.com/docker/sbx-releases/issues/180) /
[#186](https://github.com/docker/sbx-releases/issues/186)). Workarounds:

- **SSH'd into macOS**: unlock the keychain in the same shell first and retry —
  `security unlock-keychain ~/Library/Keychains/login.keychain-db`. If that
  still fails, do `sbx login` once from a local GUI session (physical machine
  or a screen-shared terminal).
- **Headless Linux**: start a session D-Bus plus
  `gnome-keyring-daemon --components=secrets` and make sure
  `DBUS_SESSION_BUS_ADDRESS` is inherited by both `sbx` and the daemon
  (see #186).
- Either way, sbx changes its authentication handling frequently, so update
  first (`brew upgrade sbx` and similar) before digging in.

## Known and unverified items

The spec.yaml files follow the
[kit spec reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference/).

**Inherited from the sibling `pnpm-biome-template`, where it was verified on
hardware** (claude template `docker/sandbox-templates:claude-code-docker`).
These are environment facts about sbx itself, so they should carry over, but
they have **not** been re-measured for this Python/uv kit:

- The base is Ubuntu 26.04 / arm64, the bundled Node is v22, `~/.codex` is
  empty (so the config seed takes effect), the agent user has passwordless
  sudo and is in the docker group, and Docker inside the VM is 29.7.1.
- `${WORKDIR}` in `~/.codex/config.toml` expands to the workspace's absolute
  path. In clone mode the workspace path **mirrors the host's absolute path**,
  so the result matches direct mode; the template's own
  `/home/agent/workspace` is left behind as an empty directory and does no
  harm.
- **`git push` over HTTPS works via header injection** — with
  `format: "token %s"`, both `gh api user` and `git push` succeed. There is no
  need to fall back to "push from the host".
- Deny-by-default networking really is in effect (domains outside the allowlist
  return 403 `no matching allow rule`). `GH_TOKEN` holds a sentinel
  (`proxy-managed`, 13 characters) and the real value is not in the VM.
- The built-in agents' authentication is proxy-managed: the
  `claudeAiOauth.accessToken` / `refreshToken` in `~/.claude/.credentials.json`
  are 26-character sentinels, so real OAuth tokens do not enter the VM.
- **The built-in claude template's default launch command is
  `claude --dangerously-skip-permissions`**, measured with `ps` inside the VM.
  A shared mixin (which cannot carry a `sandbox:` block) cannot override it.
- Approach A was verified there (claude template + Claude Max): `sbx create`
  completes the kit install without launching the agent, `sbx exec` shows
  `claude --permission-mode auto` in `ps` with no bypass flag left, and
  subscription authentication is preserved with no re-login.
- **The default policy does not allow `console.anthropic.com` / `claude.ai`**
  (measured: 403). The kit adds them.
- Using `pkill -f <pattern>` inside the VM kills your own shell, because the
  full command line matches. The `agentInstructions` say to kill by PID.
- **`claude mcp add` defaults to `local` scope** (per-cwd), and the cwd of an
  install step is not necessarily the workspace, so a registration made with
  the default scope does not show in `claude mcp list`. This kit registers no
  MCP servers, but use `-s user` if you add one.
- `claude mcp list` shows an `mcp-gateway` entry
  (`http://mcp-gateway.docker.internal/mcp`) that comes from sbx, not from any
  kit, and prints a warning that "claude.ai connectors are disabled because
  ANTHROPIC_API_KEY or another auth source is set". No API key is set — the
  proxy-managed credential is what counts as "another auth source". Only
  claude.ai organization connectors are disabled; Claude Code itself is
  unaffected.

**Not yet verified for this repository.** Update spec.yaml and this section as
you learn:

1. **The whole host checklist above.** Nothing in this Python/uv kit has been
   run on hardware yet.
2. **Whether uv's managed CPython download passes the network policy.**
   python-build-standalone is served from GitHub release assets, and the host
   serving them has changed over time — the allowlist carries both
   `objects.githubusercontent.com` and `release-assets.githubusercontent.com`
   for that reason. If `uv python install 3.14` fails during the kit install,
   this is the first thing to check.
3. **Whether the sandbox template already ships `uv`.** Every install step is
   guarded, so it works either way, but the pinned Python version and the
   install path are worth confirming.
4. **Behaviour on the codex template** — the checks above only covered the
   claude template. In particular, if the codex template already seeds
   `~/.codex/config.toml`, `onlyIfMissing` means the kit's settings will not be
   applied.
5. **Whether secrets survive `sbx rm`** — it is unverified whether a
   sandbox-scoped secret persists after the sandbox is recreated. Re-check with
   `gh api user` after recreating.
6. **Approach B is unverified** (approach A was verified on the sibling
   template). Confirm that `sbx kit validate` passes, that both `--kit`
   arguments apply, that `--dangerously-skip-permissions` is gone from the
   launch arguments, and where the OAuth limitation actually shows up. How
   `entrypoint` and `command` inheritance resolves is undocumented, so
   **always measure with `ps`**.

## Future phase: when to remove the agents from the Dev Container

Once all of the following hold, shrink the Dev Container to a "human VS Code
development environment" (in a separate PR):

- The full set of daily tasks on the sbx side (running tests, gh / PR
  operations, unattended Codex runs) has worked for 2-4 weeks without falling
  back to the Dev Container.
- Every pass-cli use case (gh, git push, task API keys) is covered by
  credential injection.
- The removal scope is settled: the agent installation block in
  `post-create.sh`, the pass-cli layer in `Dockerfile`, the auth volumes in
  `compose.yaml`, `codex-config.toml`, and the pass-cli section of the README.
