---
type: Index
title: Architecture Decision Records
description: Log of near-irreversible design decisions and the reasoning behind them
tags: [adr]
timestamp: 2026-06-30T00:00:00Z
---

# Architecture Decision Records

Record near-irreversible design decisions and **the reasoning behind them**, in chronological order. The format is a lightweight [MADR](https://adr.github.io/madr/)-style note.

## Naming

`NNNN-kebab-case-title.md` (four-digit zero-padded sequence number).

## Status vocabulary

* **Proposed** — under discussion; may not be implemented yet.
* **Accepted** — adopted; should match the current code.
* **Superseded** — replaced by a newer ADR. Note `Superseded by ADR-XXXX` in both the frontmatter `tags` and the body `# Status` section.
* **Deprecated** — retired without a direct replacement.

When the status of an ADR changes, update both the frontmatter `tags:` and the `# Status` section of the ADR body, and append an entry to [/docs/knowledge/log.md](/docs/knowledge/log.md).

## Index

* [0001-sample-decision.md](0001-sample-decision.md) — Sample. Replace with a real ADR (or delete) once you have one.
