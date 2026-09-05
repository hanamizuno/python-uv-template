# Knowledge Bundle Update Log

## 2026-06-30

* **Bootstrap**: Created `docs/knowledge/` as an OKF v0.1 bundle skeleton.
* **Sample**: Seeded one example document per subdirectory to demonstrate the expected shape. Replace them as real knowledge is added.
  * [architecture/sample-service-overview.md](/docs/knowledge/architecture/sample-service-overview.md)
  * [adr/0001-sample-decision.md](/docs/knowledge/adr/0001-sample-decision.md)
  * [conventions/sample-convention.md](/docs/knowledge/conventions/sample-convention.md)
  * [runbooks/sample-runbook.md](/docs/knowledge/runbooks/sample-runbook.md)
  * [research/sample-research.md](/docs/knowledge/research/sample-research.md)

<!--
Going forward, append entries here when you add, move, or retire a document, or
when a decision in this bundle changes status. Group entries under an ISO date
heading (`## YYYY-MM-DD`). Keep each bullet terse and link to the concrete file.
-->

## 2026-09-05

* **Moved from `.devcontainer/README.md`**: pulled agent/reference-only detail out of the human-facing README into the knowledge bundle; the README keeps only setup steps and pointers.
  * [architecture/devcontainer-agent-runtime.md](/docs/knowledge/architecture/devcontainer-agent-runtime.md) — host config inheritance, isolation modes and limits, venv/cache isolation.
  * [runbooks/devcontainer-github-pat.md](/docs/knowledge/runbooks/devcontainer-github-pat.md) — scoped GitHub PAT setup.
  * [runbooks/devcontainer-secrets-proton-pass.md](/docs/knowledge/runbooks/devcontainer-secrets-proton-pass.md) — Proton Pass task-secrets flow.
* **Moved from `.sandbox/README.md`**: same trim, for the sbx setup added on this branch — the README keeps setup/day-to-day steps only.
  * [architecture/sbx-agent-sandbox.md](/docs/knowledge/architecture/sbx-agent-sandbox.md) — clone-mode mechanics, mounting, inheritance, task-secrets model, orchestration.
  * [runbooks/sbx-setup-and-yolo-override.md](/docs/knowledge/runbooks/sbx-setup-and-yolo-override.md) — approach A/B for overriding YOLO defaults.
  * [runbooks/sbx-host-trial-checklist.md](/docs/knowledge/runbooks/sbx-host-trial-checklist.md) — hardware verification checklist.
  * [runbooks/sbx-troubleshooting-auth.md](/docs/knowledge/runbooks/sbx-troubleshooting-auth.md) — `sbx login`/`sandboxd` auth recovery.
  * [research/sbx-known-and-unverified.md](/docs/knowledge/research/sbx-known-and-unverified.md) — verified-elsewhere vs. unverified-here facts.
  * [adr/0002-coexist-sbx-with-devcontainer.md](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md) — the coexistence decision and Dev Container retirement criteria.
