---
type: ADR
title: Run sbx alongside the Dev Container, staged migration
description: Why sbx was added without removing the Dev Container's agent tooling, and when to revisit that
tags: [sbx, devcontainer, agents, accepted]
timestamp: 2026-09-05T00:00:00Z
---

# ADR-0002: Run sbx alongside the Dev Container, staged migration

## Status

Accepted — 2026-09-05

## Context

The Dev Container ([devcontainer-agent-runtime.md](/docs/knowledge/architecture/devcontainer-agent-runtime.md)) is a Linux container: no separate kernel, no granular network allow/deny, no nested Docker for the agent. [sbx](/docs/knowledge/architecture/sbx-agent-sandbox.md) (Docker Sandboxes) closes those gaps with a microVM boundary, deny-by-default networking, and credential injection that keeps real secrets out of the VM entirely. Nothing in this Python/uv kit has been run on real hardware yet — see [sbx-known-and-unverified.md](/docs/knowledge/research/sbx-known-and-unverified.md) — only a sibling pnpm template's equivalent setup has been hardware-verified.

## Decision

Add sbx configuration (`.sandbox/`) as a second, higher-assurance runtime for AI agents, without removing the agent tooling from the Dev Container. Run both in parallel until sbx has proven itself for this repository's actual daily use, then shrink the Dev Container's agent-related parts in a separate PR.

## Consequences

Retire the Dev Container's agent tooling once **all** of the following hold:

* The full set of daily tasks (running tests, `gh`/PR operations, unattended Codex runs) has worked on sbx for 2–4 weeks without falling back to the Dev Container.
* Every pass-cli use case (`gh`, `git push`, task API keys) is covered by sbx's credential injection.
* The removal scope is settled: the agent install block in `.devcontainer/post-create.sh`, the pass-cli layer in `Dockerfile`, the auth volumes in `.devcontainer/compose.yaml`, `codex-config.toml`, and the pass-cli section of `.devcontainer/README.md`.

Until then, both environments are maintained, and any behavior change to one (e.g. Codex's `approval_policy`) should be evaluated for whether it should also apply to the other rather than assumed to.
