# .sandbox

Kits for running agents inside a microVM with [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`).

- `kit/` — shared mixin (uv + Python 3.14 + prek + Codex CLI + network / credential rules)
- `claude-auto/` / `codex-approve/` — fork kits that replace the default YOLO launch commands

## Usage

**Run on the host** (not available from inside the devcontainer). Sandbox names are listed by `sbx ls`.

```bash
# Create the sandbox (--clone is mandatory; the agent is not launched yet)
sbx create --clone --kit ./.sandbox/kit claude .

# Launch (entering with `sbx run` would start the default YOLO entrypoint,
# so always enter this way)
sbx exec -it -w "$PWD" claude-<dir> claude --permission-mode auto

# Register a GitHub fine-grained PAT for this sandbox only (value entered interactively)
sbx secret set github --sandbox claude-<dir>

# List / stop / remove (rm wipes all in-VM state, unpushed commits included)
sbx ls
sbx stop <sandbox>
sbx rm <sandbox>
```

After changing a kit, `sbx rm` and recreate to pick it up.

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
