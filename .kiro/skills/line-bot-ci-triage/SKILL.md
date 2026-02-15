---
name: line-bot-ci-triage
description: Triage GitHub Actions failures for this repository quickly and consistently. Use when CI/CD runs fail, when asked to identify failing workflow steps, collect failed logs, correlate failures to known patterns, and propose minimal fixes for workflows in `.github/workflows/`.
---

# LINE Bot CI Triage

## Overview

Use this skill to diagnose GitHub Actions failures with minimal back-and-forth.
Start from failed runs, extract failed-step logs, map to known failure patterns, then propose targeted fixes.

## Workflow

1. List recent failed runs.
- Run: `./.kiro/skills/line-bot-ci-triage/scripts/gh_failed_runs.sh --limit 20`
- Filter workflow if needed:
  - `./.kiro/skills/line-bot-ci-triage/scripts/gh_failed_runs.sh --workflow "Deploy to ECR" --limit 20`

2. Inspect a specific failed run.
- Run: `./.kiro/skills/line-bot-ci-triage/scripts/gh_failed_runs.sh --run-id <id>`

3. Map to known patterns.
- Read: `references/known-failures.md`
- Confirm exact failing command and error message.

4. Propose minimal fix and verify scope.
- Patch only relevant workflow files.
- Keep deploy behavior unchanged unless required by the fix.

## Guardrails

- Prefer `gh run view <id> --log-failed` over full logs first.
- Preserve existing branch/path triggers unless explicitly asked to change.
- Treat missing credentials/config separately from code regressions.

## References

- Known CI failures: `references/known-failures.md`
- Triage script: `scripts/gh_failed_runs.sh`
