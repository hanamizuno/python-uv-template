---
type: Runbook
title: sbx — host trial checklist
description: Steps to evaluate the sbx setup on real hardware during the coexistence period with the Dev Container
tags: [sbx, agents]
timestamp: 2026-09-05T00:00:00Z
---

# sbx — host trial checklist

Use this to evaluate the sbx setup during the coexistence period (see [ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md)). None of it has been run for this repository yet — items are adapted from the sibling pnpm template, where the equivalents passed (see [sbx-known-and-unverified.md](/docs/knowledge/research/sbx-known-and-unverified.md)).

1. `sbx version` — installation check.
2. `sbx login` — sign in (browser device-code flow).
3. `sbx kit validate ./.sandbox/kit` / `./.sandbox/claude-auto` / `./.sandbox/codex-approve` — schema validation, including `extends:` resolution.
4. Verify the launch-mode override (try both approaches and compare — see [sbx-setup-and-yolo-override.md](/docs/knowledge/runbooks/sbx-setup-and-yolo-override.md)):
   - **Approach A**: `sbx create --name claude-auto-<dir> --clone --kit ./.sandbox/kit claude .` then `sbx exec -it -w "$PWD" claude-auto-<dir> claude --permission-mode auto`. Must start on subscription auth without re-login.
   - **Approach B**: `sbx run claude-auto --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto`. Must demand an API key registration (`sbx secret set anthropic`).
   - Either way: inside the VM, `git remote -v` / `ls /run/sandbox/source` show clone mode, and `ps -eo args | grep claude` shows `claude --permission-mode auto` with **no** `--dangerously-skip-permissions`.
5. `sbx secret set github --sandbox claude-auto-<dir>` → `sbx secret ls` shows sandbox scope, not global.
6. Inside the VM: `uv --version` / `uv python list` shows 3.14, `command -v codex`, `~/.local/bin/prek --version`.
7. `uv sync --frozen && uv run task lint && uv run task test_cov` passes.
8. `cat ~/.codex/config.toml` — `${WORKDIR}` has expanded to the real path.
9. `gh api user` succeeds; `echo "$GH_TOKEN"` shows a sentinel value (confirms the real value isn't in the VM). Also try `git ls-remote` and `git push --dry-run`.
10. Audit `sbx policy ls`; a `curl` to a domain outside the allowlist is denied (body starts with `Blocked by network policy`). Check especially whether uv's managed-CPython download (`astral.sh` → GitHub release assets) succeeded — the most likely thing to need an allowlist adjustment.
11. Launch Codex the same way as step 4 — `ps -eo args | grep codex` shows `codex --approve-for-me`; check whether ChatGPT subscription auth survives.
12. `command -v pass-cli` is empty — confirms the environment detection in `agentInstructions` and `AGENTS.md` holds.
13. Leave and re-enter → reconnects without re-running install. `sbx rm` and recreate → install runs. With approach A, reconnect via `sbx exec` (not `sbx run`).
14. Commit inside the VM and `git push` → reaches GitHub; can also be pulled to the host with `git fetch sandbox-claude-auto-<dir>`.
