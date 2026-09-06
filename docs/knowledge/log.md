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
* **Moved from `.sandbox/README.md`**: same trim, for the sbx setup added on this branch — the README keeps setup, day-to-day, and host hand-off steps only.
  * [runbooks/agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md) — YOLO override, clone mode, mounting, secrets, orchestration, auth troubleshooting, first-run checklist.
  * [research/sbx-verification.md](/docs/knowledge/research/sbx-verification.md) — verified-elsewhere vs. unverified-here facts.
  * [adr/0002-coexist-sbx-with-devcontainer.md](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md) — the coexistence decision and Dev Container retirement criteria.
