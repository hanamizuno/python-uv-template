---
type: Runbook
title: Task secrets via Proton Pass (pass-cli) in the devcontainer
description: How per-command secret injection works for unattended agents, and one-time host setup
tags: [devcontainer, agents, secrets, proton-pass]
timestamp: 2026-09-05T00:00:00Z
---

# Task secrets via Proton Pass (pass-cli) in the devcontainer

Agents in this devcontainer run unattended (`approval_policy = "never"`, `--dangerously-skip-permissions`) and can read anything in their environment, so task secrets (API keys, tokens) must not sit in ambient container env. Instead, [pass-cli](https://protonpass.github.io/pass-cli/) is baked into the devcontainer stage and secrets are injected per command.

## Usage (agents)

1. `.env` (git-ignored) holds only `pass://SHARE_ID/ITEM_ID/FIELD` *references* — copy `example.env` to `.env` to start. References are ID-based: vault/item *names* in the URI don't resolve. Look up IDs with `pass-cli item list --vault-name <vault> --output json` (fields `share_id` / `id`).
2. Run commands that need secrets through:
   ```bash
   PROTON_PASS_AGENT_REASON="<why you need it>" pass-cli run --env-file .env -- <cmd>
   ```
   Values resolve at spawn time, inject only into `<cmd>`'s environment, and are masked as `<concealed by Proton Pass>` in stdout/stderr. `PROTON_PASS_AGENT_REASON` is required for item access on PAT (agent) sessions and is recorded in Proton's audit log.
3. If a `pass-cli` command fails with an auth error, or there's no active session (`pass-cli info` fails), run `.devcontainer/pass-relogin` and retry.

## How the login gets there

On the host, `initialize.sh` stages the Proton Pass PAT from a 0600 file — the per-project `~/.config/proton-pass-agent/<project dir name>` when present, else the shared `~/.config/proton-pass-agent/pat` — as the git-ignored `.devcontainer/host-proton-pat`. `post-start.sh` copies it to `~/.local/state/proton-pass-agent/pat` (0600) inside the container and deletes the stage. `.devcontainer/pass-relogin` then establishes (or re-establishes) the pass-cli session from that copy whenever it has no session or reports an auth error — sessions expire after a few hours, so this lets agents recover without a container restart. The session persists in the `proton-pass` compose volume across rebuilds. No host PAT file means every step is skipped and the container works normally, just without pass-cli secrets.

Because the PAT stays resident in the container, treat container compromise as PAT compromise. The real boundary is the Proton-side scope below, not where the file sits. The agent never needs the token value — `AGENTS.md` points it at `pass-relogin` — so the value stays out of transcripts, agent memory, and model context.

## Scope model

Issue the PAT scoped to a dedicated vault (e.g. `agent-secrets`) with the `viewer` role and an expiry — pick 1–2 weeks (Proton's 60-minute default is too short for this flow) and rotate. Anything in that vault is readable by the agent, so treat "in the vault" as "handed to the agent," and keep the tokens themselves least-privilege (fine-grained GitHub PATs, etc.). Masking is hygiene, not a boundary — a subprocess can still write a secret to a file or send it over the network.

## Per-project vaults (optional)

To give a project its own blast radius, create a vault (e.g. `agents-<project>`), issue a PAT scoped to just it, and save it as `~/.config/proton-pass-agent/<project dir name>` — `initialize.sh` picks it up automatically, falling back to the shared file when absent. Name the PAT after the vault so Proton's audit log identifies which project's agent accessed what. Keep the project's repo-scoped GitHub PAT in that vault under the fixed item name `github-fine-grained` (seeded into `gh` by `pass-relogin`), and mint `.env` refs from that vault's item IDs.

## Host-side setup (one-time)

```bash
mkdir -p ~/.config/proton-pass-agent
(umask 077; read -rs PAT; printf '%s' "$PAT" > ~/.config/proton-pass-agent/pat)
```

Rotate by overwriting the file after minting a new PAT and restarting the container. Pick a path excluded from dotfile-sync tools and cloud backups.

Migrating from an existing macOS Keychain entry:

```bash
mkdir -p ~/.config/proton-pass-agent
(umask 077; security find-generic-password -w -s proton-pass-agent-pat > ~/.config/proton-pass-agent/pat)
security delete-generic-password -s proton-pass-agent-pat
```

(Repeat with `proton-pass-agent-pat-<project dir name>` → `~/.config/proton-pass-agent/<project dir name>` for per-project items.)

## Related

* [devcontainer-agent-runtime.md](/docs/knowledge/architecture/devcontainer-agent-runtime.md)
* [devcontainer-github-pat.md](/docs/knowledge/runbooks/devcontainer-github-pat.md)
