# AI Agent Dev Container

The Dev Container is also the runtime for AI coding agents (Claude Code, Codex, etc.). It is Docker Compose based: `./compose.yaml` defines the container (build, mounts, env), `devcontainer.json` layers the agent toolchain on top via [Dev Container Features](https://containers.dev/implementors/features/) and post-create setup, and the git-ignored `./compose.local.yaml` carries per-user overrides — see [Local overrides](#local-overrides-composelocalyaml) below. (`./compose.yaml` is devcontainer-only; the root `compose.yml` / `compose.dev.yml` are separate.)

## Included Features

| Feature | Source |
|---|---|
| Common utilities (non-root `vscode` user, sudo, packages) | `ghcr.io/devcontainers/features/common-utils:2` |
| GitHub CLI | `ghcr.io/devcontainers/features/github-cli:1` |
| Node.js (required by `claude-code`) | `ghcr.io/devcontainers/features/node:2` |
| Claude Code CLI | `ghcr.io/anthropics/devcontainer-features/claude-code:1` |
| Codex CLI | Installed by `./post-create.sh` with `npm install -g @openai/codex` |
| Codex plugin for Claude Code | Installed by `./post-create.sh` with `claude plugin install codex@openai-codex`, so Claude Code can delegate to Codex on demand (the `codex-rescue` subagent + `/codex` skills) |

To add another agent CLI (e.g. Cursor), drop in either an upstream Feature, a local `./<feature-id>/` directory referenced from `features`, or an idempotent install step in `./post-create.sh`.

## Initial setup

1. **Open the container** — VS Code "Reopen in Container", or headless: `devcontainer up --workspace-folder .`
2. **Authenticate** (one-time; persisted in fixed-name compose volumes, not bind-mounted from the host):
   - **Claude Code**: just start the agent — on first launch it shows the login flow inline. Do NOT pass `/login` as a CLI argument; that is a slash command for an active session and triggers the flow twice when used from the host shell.
     ```bash
     devcontainer exec --workspace-folder . claude --dangerously-skip-permissions
     ```
   - **Codex CLI**: start the agent and sign in with ChatGPT, or configure `OPENAI_API_KEY` inside the container. The first container creation copies `./codex-config.toml` into the persisted `~/.codex/config.toml` volume. The same post-create step also installs the `codex@openai-codex` plugin into Claude Code's `~/.claude` volume, so Claude Code can call Codex on demand (the `codex-rescue` subagent + `/codex` skills) without re-installing the plugin per session.
     ```bash
     devcontainer exec --workspace-folder . codex
     ```
   - **GitHub CLI** — pick one of the following:
     - **Web flow** (interactive, OAuth scopes selected at login):
       ```bash
       devcontainer exec --workspace-folder . gh auth login --hostname github.com --git-protocol https --web
       ```
     - **Seed from a host token** (e.g. `$GH_TOKEN` from `gh auth token`):
       ```bash
       devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT=$GH_TOKEN \
         sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
       ```
     - **Scoped PAT** (recommended for autonomous runs) — see [Restricting GitHub permissions](#restricting-github-permissions-pat) below.
   Credentials live in the `claude-config`, `codex-config`, and `gh-config` compose volumes (full names carry the compose project prefix, e.g. `python-uv-template-devcontainer_claude-config`) and survive `--remove-existing-container` rebuilds — the fixed names mean rebuilds reuse the same volumes instead of minting a new set per devcontainer ID.

## Host config inheritance

On every container create/start, `./initialize.sh` (an `initializeCommand`, runs on the host) stages selected host config into git-ignored files under `./`, and `./post-start.sh` seeds them inside the container:

- **Global gitignore** — resolved via `core.excludesFile` → `~/.config/git/ignore` (XDG) → `~/.gitignore`, dereferencing symlinks (e.g. Nix/home-manager targets); staged as `./host-gitignore` and copied to `~/.config/git/ignore` (git's XDG default, so no `git config` is touched). Overwritten on every start — the host is the source of truth.
- **Git identity** — `user.name` / `user.email` are read from the host's global git config (values, not the file, so includes resolve and host-only settings like credential helpers are not carried over), staged as `./host-gituser`, and applied in the container via `git config --global` on every start. Keys unset on the host are left alone.
- **Claude Code settings + statusline** — `~/.claude/settings.json` is staged with host-home paths rewritten to `/home/vscode` (so e.g. the `statusLine` command keeps working) and **deep-merged** into the container's `~/.claude/settings.json` with `jq` (host wins per key; container-only keys such as in-container plugin enables survive). `~/.claude/statusline-command.sh` is copied alongside. Auth/state (`~/.claude.json`, `~/.claude/.credentials.json`) is intentionally **not** staged — authentication stays in the container-scoped volume.

If a host file does not exist its step is a no-op and the container starts normally.

The staged `host-*` files (`host-gitignore`, `host-gituser`, `host-claude/`, `host-proton-pat`) are git-ignored local artifacts containing personal config. A `git clone` never carries them, but a plain filesystem copy (`cp -r`, zip) of a checkout would — exclude them when copying this template outside git. `host-proton-pat` briefly holds a real secret between `devcontainer up` and the container's post-start (which copies it into the container and deletes the stage), so treat a lingering copy as a token to rotate.

> **Windows hosts:** `initializeCommand` runs a bash script on the host, so native Windows needs Git Bash/WSL on `PATH` — otherwise the sync is skipped but the container still starts.

## Local overrides (`compose.local.yaml`)

`devcontainer.json` lists two compose files — `"dockerComposeFile": ["compose.yaml", "compose.local.yaml"]` — and Docker Compose merges them in order. The git-ignored `./compose.local.yaml` therefore only needs the *diff* for your personal environment (extra bind mounts, networks, `extra_hosts`); the committed config stays untouched and nothing drifts. Because compose refuses to start when a listed file is missing, `initialize.sh` auto-generates a no-op stub (`services: { app: {} }`) if the file does not exist.

Compose resolves relative paths from the project directory — the directory of the first compose file, i.e. `.devcontainer/` — so the workspace is `..` and a directory next to the repo is `../../<name>`. Example: mount a sibling directory read-only:

```yaml
# .devcontainer/compose.local.yaml (per-user override; git-ignored)
services:
  app:
    volumes:
      - ../../reference-docs:/reference-docs:ro
```

Making the target `/<dir>` keeps the container-side path relative to `/workspace` identical to the host-side path relative to the repo (`../reference-docs` both ways).

## Operating modes

- **Default (egress open)** — outbound traffic is unrestricted. Host credentials are *not* bind-mounted (Claude/Codex/`gh` auth lives in container-scoped volumes), and the host Docker socket is not exposed. The defense surface for autonomous agent runs is: non-root `vscode` user, workspace-only mount, container-scoped auth volumes. Codex is seeded with `approval_policy = "never"` and `sandbox_mode = "workspace-write"` in its container-scoped config, which lets it work without pauses while keeping writes scoped to the workspace. Precisely because agents run unattended with network access, task secrets (API keys, tokens) are delivered per-command via `pass-cli run` instead of ambient container env — see "Task secrets via Proton Pass (pass-cli)" below.
- **Isolated mode (optional)** — for a stricter sandbox, create a Docker network with no egress and attach the container to it:
  ```bash
  docker network create --internal agent-internal
  ```
  Then attach the container to it in `./compose.local.yaml`:
  ```yaml
  services:
    app:
      networks: [agent-internal]
  networks:
    agent-internal:
      external: true
  ```
  Outbound is fully blocked, so resolve dependencies (`uv sync`, etc.) before switching, and run a proxy sidecar if the agent still needs API access.

## What this isolation *does not* cover

The container compresses the blast radius from "everything the host user can touch" down to "the workspace + container-scoped auth volumes" — but it is still a Linux container, not a microVM. Specifically, this template does **not** provide:

- A separate kernel (a container-escape kernel exploit is not contained).
- Granular network allow/deny lists (only the binary `--network=internal` mode above; the previous iptables-based allowlist was removed because it was hard to keep correct).
- A nested Docker daemon for safely building/running containers from inside the agent session (the host Docker socket is intentionally not mounted).

If you need any of those, run the agent inside a higher-assurance sandbox such as [Docker Sandbox](https://docs.docker.com/ai/sandboxes/) (microVM kernel boundary, allow/deny networking, per-sandbox Docker daemon) and treat this devcontainer as the inner workspace.

**Host loopback access is intentionally not opened.** `host.docker.internal` is not added by default — opening it would expose every `0.0.0.0`-bound host service (local LLM servers, dev DBs, debug dashboards) to the agent. If you specifically need it — e.g. to point an agent at a locally hosted OpenAI-compatible endpoint — add it as a local override, not a project default:

```yaml
# .devcontainer/compose.local.yaml (per-user override; git-ignored)
services:
  app:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Then bind the host service to `0.0.0.0` (not `127.0.0.1`) so the bridge network can reach it, and configure the agent to use `http://host.docker.internal:<port>`.

## Restricting GitHub permissions (PAT)

When Claude Code runs with `--dangerously-skip-permissions`, it inherits whatever scopes the stored `gh` token has. To limit blast radius, seed the volume with a dedicated PAT instead of your everyday `$GH_TOKEN`.

**Steps:**

1. Issue a PAT in GitHub:
   - **Quick link** — open this [prefilled template](https://github.com/settings/personal-access-tokens/new?name=agent-devcontainer&description=Agent%20devcontainer%20baseline&expires_in=90&contents=write&pull_requests=write&issues=write&metadata=read&actions=read&workflows=write) (Repository permissions: `Contents: Write`, `Pull requests: Write`, `Issues: Write`, `Metadata: Read`, `Actions: Read`, `Workflows: Write`; 90-day expiry), pick the target repo(s), and click *Generate token*. Tweak the URL to derive narrower templates (e.g. drop `pull_requests=write` for a read-only review token; bump `actions=read` to `actions=write` for workflow dispatch; drop `workflows=write` if the agent should not edit `.github/workflows/*.yml`). `Administration: Write` is intentionally not in the baseline — add it manually when you actually need repo creation / settings changes.
   - **Fine-grained** (preferred for narrow blast radius) — pick the target repo(s) and the minimum permissions from the table below.
   - **Classic** with the smallest scope set that covers your needs (e.g. `repo` only) — use this if a `gh` operation you rely on is not yet supported by fine-grained PATs.
2. Replace any existing auth so scopes don't accumulate:
   ```bash
   devcontainer exec --workspace-folder . gh auth logout --hostname github.com
   ```
3. Seed the volume with the new PAT (avoid leaving the value in shell history — leading-space the line, or read from a file):
   ```bash
    GH_PAT='github_pat_xxx' devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT=$GH_PAT \
      sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
   unset GH_PAT
   ```
   Or, from a token file:
   ```bash
   devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT="$(cat ~/.config/agent-gh-pat)" \
     sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
   ```
4. Verify the granted scopes:
   ```bash
   devcontainer exec --workspace-folder . gh auth status
   devcontainer exec --workspace-folder . sh -c '
     gh auth token | xargs -I{} curl -sI -H "Authorization: token {}" https://api.github.com/user \
       | grep -iE "x-oauth-scopes|x-accepted"
   '
   ```
   Classic PATs show granted scopes via `x-oauth-scopes`. Fine-grained PATs show empty there — read the resource permissions on the PAT settings page directly.

**Suggested minimum permissions (fine-grained):**

| Operation Claude should perform | Permission |
|---|---|
| Read issues / PRs / repo metadata | `Issues: Read`, `Pull requests: Read`, `Metadata: Read` |
| Comment on / open / close PRs | `+ Pull requests: Write`, `Issues: Write` |
| HTTPS `git push` / commit | `+ Contents: Write` (repo-scoped) |
| GitHub Actions read/dispatch | `+ Actions: Read` (or `Write` if dispatch needed) |
| Edit workflow YAML in `.github/workflows/` | `+ Workflows: Write` |
| Repository creation / settings | `+ Administration: Write` (org may require approval) |

**Notes / gotchas:**

- Fine-grained PATs do not yet cover every `gh` subcommand — if you hit a 403 or "PAT not supported" error, fall back to a tightly-scoped classic PAT.
- The token sits in `~/.config/gh/hosts.yml` inside the volume. Anyone with shell access in the container can read it, so treat compromise of the container as compromise of the token's scope.
- Rotate by repeating step 2 + 3 — you do not need to recreate the volume.
- Alternatively, `.devcontainer/pass-relogin` seeds `gh auth` from the `github-fine-grained` item in the agent vault when the volume has no auth yet (see the next section).

## Task secrets via Proton Pass (pass-cli)

Agents here run unattended (`approval_policy = "never"`, `--dangerously-skip-permissions`) and can read anything in their environment, so task secrets must not sit in ambient container env — which is exactly what a `remoteEnv`/`containerEnv` passthrough would do. Instead, the [Proton Pass CLI](https://protonpass.github.io/pass-cli/) is baked into the devcontainer stage and secrets are injected per command:

1. `.env` (git-ignored) holds only `pass://SHARE_ID/ITEM_ID/FIELD` *references* — copy `example.env` to `.env` to start. References are ID-based: vault or item *names* in the URI do not resolve (pass-cli passes them through untouched). Look the IDs up with `pass-cli item list --vault-name <vault> --output json` (fields `share_id` / `id`). References are identifiers, not values, so `example.env` is safe to commit; the real `.env` stays ignored as insurance against pasting an actual token into it.
2. Run commands that need secrets through `pass-cli run`:

   ```bash
   PROTON_PASS_AGENT_REASON="<why you need it>" pass-cli run --env-file .env -- <cmd>
   ```

   Values are resolved at spawn time, injected only into `<cmd>`'s environment, and masked as `<concealed by Proton Pass>` in stdout/stderr. `PROTON_PASS_AGENT_REASON` is required for item access on PAT (agent) sessions — `pass-cli run` fails with an error without it — and the value is recorded in Proton's audit log.

**How the login gets there:** on the host, `initialize.sh` stages the Proton Pass personal access token (PAT) from a 0600 file — the per-project `~/.config/proton-pass-agent/<project dir name>` when present, else the shared `~/.config/proton-pass-agent/pat` — as the git-ignored `.devcontainer/host-proton-pat`, the same host-* staging idiom as the config inheritance above, so no extra mount is involved. `post-start.sh` copies it to `~/.local/state/proton-pass-agent/pat` (0600) inside the container and deletes the stage. Login itself is agent-driven: `.devcontainer/pass-relogin` establishes (or re-establishes) the session from that copy whenever pass-cli has no session or reports an auth error — pass-cli sessions expire after a few hours, and this lets agents recover without a container restart. The session persists in the `proton-pass` compose volume across rebuilds. No host PAT file means every step is skipped and the container works normally, just without pass-cli secrets.

Because the PAT stays resident in the container, treat container compromise as PAT compromise. The real boundary is the Proton-side scope below — a dedicated least-privilege vault, an expiry, and revocation — not where the file sits. (The agent never needs the token value: instructions in `AGENTS.md` point it at `pass-relogin`, so the value stays out of transcripts, agent memory, and model context.)

**Scope model:** issue the PAT scoped to a dedicated vault (e.g. `agent-secrets`) with the `viewer` role and an expiry. Proton's default of 60 minutes is too short for this flow — pick something like 1–2 weeks and rotate. Anything in that vault is readable by the agent — treat "in the vault" as "handed to the agent", and keep the tokens themselves least-privilege (fine-grained GitHub PATs, etc.). Masking is hygiene, not a boundary: a subprocess can still write a secret to a file or send it over the network.

**Per-project vaults (optional):** to give this project its own blast radius, create a vault (e.g. `agents-<project>`), issue a PAT scoped to just that vault, and save it as `~/.config/proton-pass-agent/<project dir name>` — `initialize.sh` picks it up automatically and falls back to the shared file when absent, so the repo needs no config. Name the PAT after the vault so Proton's audit log identifies which project's agent accessed what. Keep the project's repo-scoped GitHub PAT in that vault under the fixed item name `github-fine-grained` (seeded into `gh` by `pass-relogin`), and mint the `.env` refs from that vault's item IDs.

**Host-side setup (one-time, any OS with bash):**

```bash
mkdir -p ~/.config/proton-pass-agent
(umask 077; read -rs PAT; printf '%s' "$PAT" > ~/.config/proton-pass-agent/pat)
```

Rotate by overwriting the file after minting a new PAT and restarting the container. Pick a path excluded from dotfile-sync tools and cloud backups. Previously registered the PAT in the macOS Keychain? Migrate with:

```bash
mkdir -p ~/.config/proton-pass-agent
(umask 077; security find-generic-password -w -s proton-pass-agent-pat > ~/.config/proton-pass-agent/pat)
security delete-generic-password -s proton-pass-agent-pat
```

(Repeat with `proton-pass-agent-pat-<project dir name>` → `~/.config/proton-pass-agent/<project dir name>` for per-project items.)

## .venv and uv cache isolation

`.venv` contains platform-specific binaries (the CPython interpreter, native wheels), so sharing it between the host (e.g. macOS) and the container (Linux) forces a reinstall on every switch. This template therefore:

- **`.venv`** — a compose volume (`venv`) masks the host's `.venv` on the bind mount. The host keeps its own venv untouched; the container keeps a Linux venv inside the volume. Neither side needs reinstalling when you switch.
- **uv cache** — a compose volume (`uv-cache`) is mounted at `~/.cache/uv` (uv's default cache location), so downloaded wheels survive container rebuilds. `UV_LINK_MODE=copy` is already set in the Dockerfile, so the volume boundary simply means copies instead of hardlinks.

To redo the environment, run `rm -rf .venv && uv sync --frozen` inside the container (the host is unaffected). For a completely fresh start, remove the volumes with `docker volume rm` and rebuild.

## Notes

- Pulling Feature updates: `devcontainer up --workspace-folder . --remove-existing-container` (or VS Code → "Rebuild Container").
- Host Docker socket is intentionally not mounted; the agent cannot manipulate host containers.
