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
  * `architecture/devcontainer-agent-runtime.md` (retired 2026-11-13) — host config inheritance, isolation modes and limits, venv/cache isolation.
  * `runbooks/devcontainer-github-pat.md` (retired 2026-11-13) — scoped GitHub PAT setup.
  * `runbooks/devcontainer-secrets-proton-pass.md` (retired 2026-11-13) — Proton Pass task-secrets flow.
* **Moved from `.sandbox/README.md`**: same trim, for the sbx setup added on this branch — the README keeps setup, day-to-day, and host hand-off steps only.
  * [runbooks/agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md) — YOLO override, clone mode, mounting, secrets, orchestration, auth troubleshooting, first-run checklist.
  * [research/sbx-verification.md](/docs/knowledge/research/sbx-verification.md) — verified-elsewhere vs. unverified-here facts.
  * [adr/0002-coexist-sbx-with-devcontainer.md](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md) — the coexistence decision and Dev Container retirement criteria.

## 2026-11-09

* **Updated for sbx v0.51.0 / kit spec v3**: the built-in agents became v3 kits that cannot compose with v2 kits.
  * [runbooks/agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md) — launch via environment files (`sbx env run`) instead of `sbx create` + `sbx exec`; fork kits retired; v2 → v3 field mapping; host settings now copied by a postCreate overlay.
  * [research/sbx-verification.md](/docs/knowledge/research/sbx-verification.md) — replaced with v0.51.0 measurements (uv page-size crash and workaround, codex kit's own seed, secrets after creation, read-only skills, no git identity).

## 2026-11-13

* **Remove**: retired the Dev Container; sbx is now the only agent runtime.
  * [adr/0003-retire-devcontainer.md](/docs/knowledge/adr/0003-retire-devcontainer.md) — the decision; [ADR-0002](/docs/knowledge/adr/0002-coexist-sbx-with-devcontainer.md) is now Superseded.
  * Deleted `architecture/devcontainer-agent-runtime.md`, `runbooks/devcontainer-github-pat.md`, `runbooks/devcontainer-secrets-proton-pass.md`. The PAT scope guidance moved to [runbooks/agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md) ("Restricting GitHub permissions (PAT)").
