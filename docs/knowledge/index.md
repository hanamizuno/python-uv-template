---
okf_version: "0.1"
---

# Knowledge Bundle

This directory is a knowledge bundle that follows the [Open Knowledge Format (OKF) v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) spec. It is meant as a shared memory that both AI agents and humans read and write in plain Markdown.

This template ships only the **skeleton**: the directory layout, the reserved files (`index.md` / `log.md`), and one sample document per subdirectory that demonstrates the expected shape. Replace the samples with real content as your project grows — do not let placeholder docs accumulate.

Unlike user-facing docs (`README.md`) or AI agent guidelines (`AGENTS.md`), this bundle is the place to capture **decisions, rationale, and operational knowledge that are not obvious from the code or git history**. If something can be reconstructed by reading the codebase or `git log`, do not write it here.

## Layout

* [architecture/](architecture/) — system structure, data flow, staged-build plans
* [adr/](adr/) — Architecture Decision Records (decisions and why we made them)
* [conventions/](conventions/) — testing, error handling, and other repository-wide conventions
* [runbooks/](runbooks/) — incident response and operational procedures
* [research/](research/) — snapshots of investigations and comparative analyses
* [log.md](log.md) — bundle-wide changelog

## OKF rules of thumb

* `index.md` and `log.md` are reserved filenames — do not use them for concept documents.
* Only the bundle-root `index.md` may carry an `okf_version` frontmatter field.
* Every other `.md` file **must have frontmatter**, and at minimum must include a `type`. Reserved files are exempt: `log.md` carries no frontmatter, and the subdirectory `index.md` files in this template carry `type: Index` by convention, not requirement.
* Prefer **bundle-root-relative** links (start with `/`, e.g. `/docs/knowledge/architecture/sample-service-overview.md`). This survives file moves better than relative links.
* One concept per file. Directory nesting expresses parent/child relationships.
* Recommended fields: `type` (required), `title`, `description`, `resource`, `tags`, `timestamp`.
* `timestamp` is ISO 8601 (e.g. `2026-06-30T00:00:00Z`).
* When you add or update a document, update the relevant subdirectory `index.md`, and append to [log.md](log.md) if the change is worth tracking bundle-wide.

## Template for a new concept

```markdown
---
type: ADR  # or Architecture Note / Runbook / Convention / Reference, etc.
title: Short, descriptive title
description: One-line summary used for previews and search
tags: [area-tag, status-tag]
timestamp: 2026-06-30T00:00:00Z
---

# Body
```

The `type` vocabulary is intentionally not centralized. Pick whatever fits your domain — readers (humans and agents) are expected to tolerate unknown `type` values. In this template the samples use `Architecture Note`, `ADR`, `Convention`, `Runbook`, and `Reference`.
