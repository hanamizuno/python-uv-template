---
type: Index
title: Architecture
description: System structure, data flow, and staged-build plans
tags: [architecture]
timestamp: 2026-06-30T00:00:00Z
---

# Architecture

Notes that explain **how the system is put together and why**. Use this directory for service topologies, data-flow diagrams, staged-build plans, and other structural decisions whose rationale is not obvious from the code.

Keep these documents complementary to the code and to `README.md` — record the *why* and the *operational implications*, not the configuration values themselves.

## Index

* [devcontainer-agent-runtime.md](devcontainer-agent-runtime.md) — Dev Container as AI agent runtime: host config inheritance, isolation modes and limits, venv/cache isolation.
* [sbx-agent-sandbox.md](sbx-agent-sandbox.md) — sbx (Docker Sandboxes) as an agent runtime: microVM isolation, clone mode, credential model, relation to the Dev Container.
* [sample-service-overview.md](sample-service-overview.md) — Sample. Replace with a real architecture note (or delete) once you have one.
