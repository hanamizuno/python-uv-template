---
type: ADR
title: Retire the Dev Container; sbx is the only agent runtime
description: Why the Dev Container was removed entirely in favor of Docker Sandboxes (sbx)
tags: [sbx, devcontainer, agents, accepted]
timestamp: 2026-11-13T00:00:00Z
---

# ADR-0003: Retire the Dev Container; sbx is the only agent runtime

## Status

Accepted — 2026-11-13. Supersedes [ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md).

## Context

[ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md) ran [sbx](/docs/knowledge/runbooks/agent-sandbox-sbx.md) alongside the Dev Container as a staged migration. Since then sbx has moved to kit spec v3 and environment files (`sbx env run`), and covers the agent workloads this template targets: tests and lint, `gh` / PR operations, unattended Codex runs, and task secrets through proxy credential injection. Maintaining both runtimes meant keeping two toolchain definitions, two Codex configs, and two secret flows (pass-cli vs. `sbx secret`) in step. The sibling pnpm template already dropped its Dev Container on 2026-10-28.

## Decision

Remove the Dev Container entirely rather than only its agent tooling: `.devcontainer/`, the `devcontainer` stage of `Dockerfile`, the Proton Pass / pass-cli secret flow and `example.env`, the `devcontainers` Dependabot ecosystem, and the Dev Container docs. Humans develop on the host with `uv` (or `compose.dev.yml`); AI agents run in sbx.

## Consequences

* One agent runtime to maintain. The scoped-PAT guidance moved to the sbx runbook.
* No VS Code "Reopen in Container" workflow. Anyone who wants one has to add it back in their derived project.
* sbx runs only on the host and requires a Docker account and supported OS — agents cannot run on machines where sbx is unavailable.
