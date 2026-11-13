# .sandbox

Kits for running agents inside a microVM with [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`), written to [kit spec v3](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md) (sbx v0.51.0+).

- `kit/` — shared mixin (uv + Python 3.14 + prek + Codex CLI + network / credential rules)
- `claude-auto/` / `codex-approve/` — [environment files](https://docs.docker.com/ai/sandboxes/configuration/environment-files/) (`sbxenv.yaml`): agent + kit + clone mode, with the built-in YOLO launch command replaced
- `host-claude/` + `stage-host-claude.sh` — opt-in overlay that brings your host Claude Code settings

## Usage

**Run on the host** (not available from inside a sandbox). Sandboxes are named `claude-<dir>` / `codex-<dir>` after the checkout directory (`sbx ls`).

```bash
# Preview what gets created (sandbox, kit, git remote, launch command)
sbx env plan ./.sandbox/claude-auto

# Create on first run, then attach; later runs re-attach (asks for approval once).
# Always enter this way — `sbx run` / `sbx env exec` start the default YOLO launch.
sbx env run ./.sandbox/claude-auto

# Register a GitHub fine-grained PAT for this sandbox only (value entered interactively;
# takes effect immediately, no recreate needed)
sbx secret set github --sandbox claude-<dir>

# Codex works the same way
sbx env run ./.sandbox/codex-approve

# List / stop / remove (env rm wipes all in-VM state, unpushed commits included,
# plus the sandbox's secrets and its sandbox-<name> git remote)
sbx ls
sbx stop claude-<dir>
sbx env rm ./.sandbox/claude-auto
```

Arguments after `--` **replace** the launch arguments, so restate the permission flag: `sbx env run ./.sandbox/claude-auto -- --permission-mode auto --continue`.

After changing a kit, `sbx env rm` and run again to pick it up.

### Optional: bring your host Claude Code settings

Opt-in. Layer the `host-claude` overlay on top: at creation it copies `~/.claude/settings.json` (host-home paths rewritten) and `statusline-command.sh` into the sandbox with `sbx cp`, and launches Claude Code with `--settings` pointing at the copy.

```bash
sbx env run ./.sandbox/claude-auto ./.sandbox/host-claude
```

Pass both paths on every run (the overlay is what adds `--settings`). To pick up host changes, `sbx env rm` and run again. To stop, drop the overlay and recreate. Why a separate file instead of merging: [runbook](../docs/knowledge/runbooks/agent-sandbox-sbx.md#what-sbx-inherits-automatically).

## Getting the work back to the host

The sandbox exposes its clone as a `sandbox-<sandbox>` remote while it is running.

```bash
# Just look at the diff
git fetch sandbox-claude-<dir>
git diff HEAD...sandbox-claude-<dir>/agent/work
```

```bash
# Pull it in
git fetch sandbox-claude-<dir>

# first time only — track the sandbox branch, but push to origin
git branch --set-upstream-to=sandbox-claude-<dir>/feat/foo
git config branch.feat/foo.pushRemote origin

# afterwards
git pull --ff-only
```

Details: [docs/knowledge/runbooks/agent-sandbox-sbx.md](../docs/knowledge/runbooks/agent-sandbox-sbx.md) / verification status: [docs/knowledge/research/sbx-verification.md](../docs/knowledge/research/sbx-verification.md)
