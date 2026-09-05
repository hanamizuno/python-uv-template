# AI Agent Sandbox (Docker Sandboxes / sbx)

Configuration for running AI coding agents inside a microVM with [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`). It **coexists** with the [Dev Container](../.devcontainer/README.md) — it does not replace it (staged migration; see [ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md)).

> **`sbx` runs on the host OS.** You cannot use it from inside the Dev Container.

## Positioning

Compared to the Dev Container's Linux-container boundary, sbx adds a microVM (separate kernel), deny-by-default networking (an allowlist, no UDP/ICMP), credential injection that keeps real API keys/tokens out of the VM, and a per-sandbox Docker daemon.

- Interactive human development in VS Code → **Dev Container**
- Unattended agent runs, or anything needing strong isolation → **sbx**

Full comparison and rationale: [sbx-agent-sandbox.md](/docs/knowledge/architecture/sbx-agent-sandbox.md).

## Prerequisites and install

- macOS 14 (Sonoma)+ on Apple Silicon, Windows 11, or Ubuntu 24.04+ with KVM enabled
- Docker Desktop / Docker Engine are **not required** (sbx is a standalone microVM runtime and coexists with an existing Docker setup such as Colima)

```bash
brew install docker/tap/sbx   # macOS; see the official docs for other OSes
sbx version
sbx login   # sbx's own auth, separate from `docker login`; opens a browser device-code flow
```

Pick **Locked Down** or **Balanced** for the default network policy when asked — the kit adds the domains it needs, and you can adjust later with `sbx policy`.

## Initial setup

The built-in agents default to YOLO launch commands, so this template overrides them via `sbx create` + `sbx exec` (keeps subscription auth — Claude Max / ChatGPT). For the alternative (fork kits, API-key billing) and the reasoning behind this approach, see [sbx-setup-and-yolo-override.md](/docs/knowledge/runbooks/sbx-setup-and-yolo-override.md).

```bash
cd <this repository's checkout>

# 1) Create the sandbox (does not launch the agent yet). --clone is mandatory
#    (see the architecture note above) — approve the kit's credentials prompt.
sbx create --name claude-auto-<dir> --clone --kit ./.sandbox/kit claude .

# 2) Launch via `sbx exec`, not `sbx run` (which would start the YOLO default)
sbx exec -it -w "$PWD" claude-auto-<dir> claude --permission-mode auto

# 3) Scope a GitHub PAT to this sandbox alone (never `-g`/global — that would
#    leak it into every future sandbox, including other repos)
sbx secret set github --sandbox claude-auto-<dir> -t "<fine-grained PAT>"
```

Codex works the same way, with `--kit ./.sandbox/kit codex .`, `sbx exec ... codex --approve-for-me`, and `sbx secret set openai`.

Use `--name` explicitly only when you want several sandboxes for the same workspace/agent in parallel. The first run needs per-agent authentication (browser login); state persists until `sbx rm`.

## Day-to-day operation

- `sbx run` in the same workspace reconnects to the existing sandbox (**except with approach A** — always reconnect via `sbx exec`, or you get the YOLO default).
- `sbx ls` / `sbx stop <name>` / `sbx rm <name>` (rm destroys all in-VM state, including unpushed commits in clone mode).
- After changing a kit: `sbx rm` then recreate.
- Commit and `git push` to hand off work — see [sbx-agent-sandbox.md](/docs/knowledge/architecture/sbx-agent-sandbox.md) for pulling changes back to the host without pushing, and for mounting extra host folders.

## Task secrets and network policy

Use `sbx secret set <service> --sandbox <name> -t "<value>"` plus a `credentials` entry in the kit (the Dev Container's pass-cli flow is not used here) — see [sbx-agent-sandbox.md](/docs/knowledge/architecture/sbx-agent-sandbox.md) for how this compares to pass-cli.

Audit the allowlist with `sbx policy ls`. When probing from inside the VM, judge by the **response body**, not the HTTP status — a denial's body starts with `Blocked by network policy`; allowed domains return 4xx/404 routinely too.

## More detail

- [sbx-agent-sandbox.md](/docs/knowledge/architecture/sbx-agent-sandbox.md) — clone-mode rationale and operational differences, mounting host folders, what sbx inherits automatically, orchestration (delegating to Codex), task-secrets comparison.
- [sbx-setup-and-yolo-override.md](/docs/knowledge/runbooks/sbx-setup-and-yolo-override.md) — approach A vs. B for overriding the YOLO defaults, in full.
- [sbx-host-trial-checklist.md](/docs/knowledge/runbooks/sbx-host-trial-checklist.md) — checklist for evaluating this setup on real hardware.
- [sbx-troubleshooting-auth.md](/docs/knowledge/runbooks/sbx-troubleshooting-auth.md) — recovering from `sbx login` / authentication failures.
- [sbx-known-and-unverified.md](/docs/knowledge/research/sbx-known-and-unverified.md) — facts carried over from a sibling template vs. what's unverified for this one.
- [ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md) — why sbx and the Dev Container coexist, and the criteria for retiring agents from the Dev Container.
