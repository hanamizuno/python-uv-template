---
type: Runbook
title: Sample — Runbook title
description: Sample runbook. Delete or replace with a real procedure.
tags: [sample]
timestamp: 2026-06-30T00:00:00Z
---

# Sample — Runbook title

> **This is a sample runbook** included with the template to show the expected shape. Replace it with a real procedure, or delete it once you have one.

## When to use this

The signal that tells the operator this runbook applies — an alert, an error message, a customer report, a metric crossing a threshold. Be specific enough that an operator at 3 a.m. can match the signal in front of them to this runbook without ambiguity.

## Pre-flight checks

* Quick checks to confirm the runbook actually applies (and to rule out look-alike incidents).
* Access / credentials / tooling the operator needs in hand before starting.

## Steps

1. The first command or action, with the exact invocation.
2. The next step, with the expected output or observable change.
3. ...

Number the steps. Inline the exact commands. Where a step has a non-obvious failure mode, call it out immediately under that step.

## How to confirm it worked

The concrete signal that proves the incident is resolved (a green check on a dashboard, a specific log line, a smoke test that now passes). Without this, an operator cannot know when to stop.

## If it does not work

* What to try next.
* When to escalate, and to whom.

## Postmortem hooks

* Things to record for the postmortem while they are fresh (timestamps, commands run, side effects observed).
