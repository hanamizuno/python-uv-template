---
type: Runbook
title: sbx — overriding the built-in YOLO launch defaults
description: Approach A (sbx create + sbx exec, keeps subscription auth) vs. approach B (fork kits, API-key billing)
tags: [sbx, agents]
timestamp: 2026-09-05T00:00:00Z
---

# sbx — overriding the built-in YOLO launch defaults

The built-in sbx agents default to YOLO:

- `claude` → `claude --dangerously-skip-permissions`
- `codex` → `codex --dangerously-bypass-approvals-and-sandbox`

This template replaces them:

- `claude-auto` → `claude --permission-mode auto` (the model judges permissions, nothing bypassed)
- `codex-approve` → `codex --approve-for-me` (keeps workspace-write; escalated approvals go to automatic review)

**Passing flags through `sbx run agent -- --permission-mode auto` does not work** — arguments starting with a flag are appended *after* the defaults, so `--dangerously-skip-permissions` survives. Use one of the two approaches below; which one depends on how you authenticate.

## Approach A: `sbx create` + `sbx exec` (keeps subscription auth)

Separate creating the sandbox from launching the agent, so you never hit the default YOLO entrypoint and the agent type stays the built-in `claude`/`codex`:

```bash
sbx create --name claude-auto-<dir> --clone --kit ./.sandbox/kit claude .
sbx exec -it -w "$PWD" claude-auto-<dir> claude --permission-mode auto

sbx create --name codex-approve-<dir> --clone --kit ./.sandbox/kit codex .
sbx exec -it -w "$PWD" codex-approve-<dir> codex --approve-for-me
```

The built-in agents' proxy-managed OAuth keeps working — credential injection isn't tied to "the first process launched," so the boundary holds for a process started with `sbx exec` in the same sandbox.

Caveats:

- **Reconnect with `sbx exec`, not `sbx run`** — `sbx run` starts the default YOLO entrypoint.
- Omitting `--name` names the sandbox `<agent>-<dir>` (no `-auto`/`-approve` prefix) — substitute the real name (`sbx ls`, or `$SANDBOX_NAME` inside the VM) wherever a sandbox name is used.
- This combination isn't published as a complete recipe in the official docs — "create a built-in sandbox, exec the same binary with different flags, keep OAuth" is this template's own inference, verified on hardware for the sibling pnpm template (claude template + Claude Max) — see [sbx-known-and-unverified.md](/docs/knowledge/research/sbx-known-and-unverified.md).

## Approach B: fork kits (API-key billing)

`sandbox.entrypoint`/`sandbox.command` can only appear in a `kind: sandbox` kit (a mixin kit can't carry a `sandbox:` block), so thin fork kits sit alongside the shared mixin, each just `extends`-ing a built-in agent: [claude-auto/spec.yaml](/.sandbox/claude-auto/spec.yaml), [codex-approve/spec.yaml](/.sandbox/codex-approve/spec.yaml).

```bash
sbx run claude-auto   --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto
sbx run codex-approve --clone --kit ./.sandbox/kit --kit ./.sandbox/codex-approve
```

A fork kit inherits image, credentials, network allowances, volumes, MCP wiring, and agent instructions, overriding only the launch command — but it must declare both `entrypoint` and `command` explicitly (effective command = `entrypoint` + `command`, and which of the two carries the parent's bypass flag isn't documented). Declaring only `entrypoint` risks silently leaving YOLO in place; declaring both fails safe either way.

> **Authentication constraint:** a kit that `extends` a built-in agent cannot use proxy-managed OAuth. Register an API key on the host before first launch (`sbx secret set anthropic` / `sbx secret set openai`). Using `/login` inside the VM stores the real token *inside* the VM — a departure from "real values never enter the VM." Use approach A to stay on subscription billing.

## Verifying either approach worked

Inside the VM: `ps -eo args | grep claude` (or `codex`) should show the replacement command with **no bypass flag** left. See [sbx-host-trial-checklist.md](/docs/knowledge/runbooks/sbx-host-trial-checklist.md) for the full verification checklist.
