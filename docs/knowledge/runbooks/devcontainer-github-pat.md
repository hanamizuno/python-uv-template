---
type: Runbook
title: Restrict the devcontainer's GitHub token (PAT)
description: Issue and seed a scoped PAT so agents don't inherit your full-access gh token
tags: [devcontainer, agents, github, security]
timestamp: 2026-09-05T00:00:00Z
---

# Restrict the devcontainer's GitHub token (PAT)

## When to use this

Claude Code with `--dangerously-skip-permissions` inherits whatever scopes the stored `gh` token has. Use this to seed a dedicated, narrowly-scoped PAT instead of your everyday token, to limit blast radius.

## Steps

1. Issue a PAT in GitHub — one of:
   * **Quick link** — a [prefilled fine-grained template](https://github.com/settings/personal-access-tokens/new?name=agent-devcontainer&description=Agent%20devcontainer%20baseline&expires_in=90&contents=write&pull_requests=write&issues=write&metadata=read&actions=read&workflows=write) (`Contents: Write`, `Pull requests: Write`, `Issues: Write`, `Metadata: Read`, `Actions: Read`, `Workflows: Write`; 90-day expiry). Tweak the URL's query params for a narrower/wider grant (e.g. drop `pull_requests=write` for read-only review, bump `actions=read` to `write` for dispatch, drop `workflows=write` if the agent shouldn't touch `.github/workflows/*.yml`).
   * **Fine-grained**, hand-picked — the minimum permissions from the list below.
   * **Classic**, smallest scope set (e.g. `repo` only) — use if a `gh` operation you need isn't yet supported by fine-grained PATs.
2. Replace any existing auth so scopes don't accumulate:
   ```bash
   devcontainer exec --workspace-folder . gh auth logout --hostname github.com
   ```
3. Seed the volume with the new PAT (avoid leaving the value in shell history):
   ```bash
   GH_PAT='github_pat_xxx' devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT=$GH_PAT \
     sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
   unset GH_PAT
   ```
   Or from a token file:
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
   Classic PATs show granted scopes via `x-oauth-scopes`. Fine-grained PATs show empty there — check the resource permissions on the PAT settings page instead.

## Suggested minimum permissions (fine-grained)

* Read issues / PRs / repo metadata — `Issues: Read`, `Pull requests: Read`, `Metadata: Read`
* Comment on / open / close PRs — add `Pull requests: Write`, `Issues: Write`
* HTTPS `git push` / commit — add `Contents: Write` (repo-scoped)
* GitHub Actions read/dispatch — add `Actions: Read` (or `Write` if dispatch needed)
* Edit workflow YAML in `.github/workflows/` — add `Workflows: Write`
* Repository creation / settings — add `Administration: Write` (org may require approval)

## Notes / gotchas

* Fine-grained PATs don't yet cover every `gh` subcommand — on a 403 or "PAT not supported" error, fall back to a tightly-scoped classic PAT.
* The token sits in `~/.config/gh/hosts.yml` inside the volume; anyone with container shell access can read it, so treat container compromise as token compromise.
* Rotate by repeating steps 2–3 — no need to recreate the volume.
* `.devcontainer/pass-relogin` can also seed `gh auth` from the `github-fine-grained` item in the agent vault when the volume has no auth yet — see [devcontainer-secrets-proton-pass.md](/docs/knowledge/runbooks/devcontainer-secrets-proton-pass.md).
