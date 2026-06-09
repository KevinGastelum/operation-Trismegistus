# Warren Project Contract

This repository is Warren-aware. Read this before dispatching any Warren run.

## Warren Files

- `.warren/config.yaml` — default agent/runtime/branch behavior (review-first;
  `mergeStrategy: manual`).
- `.warren/triggers.yaml` — scheduled runs (commented/disabled by default).
- `.warren/preview.yaml` — optional preview server (template).
- `.warren/pr-template.md` — PR body template (reminds humans to review).

## Agent Rules

1. Read `CLAUDE.md` before making changes.
2. Prefer existing Seeds/Plot/Mulch context if those tools are present.
3. Keep Warren prompts bounded, scoped, and testable.
4. Do not leak tokens or `.env` values.
5. Treat Warren output branches as **untrusted until reviewed**.
6. Do not enable cron triggers without explicit human approval.
7. Do not set or request auto-merge unless the human explicitly asks.
8. Respect this project's own safety rules (see CLAUDE.md / docs).

## Dispatch Prompt Checklist

Every Warren dispatch prompt must include:

- objective
- relevant files / directories
- constraints
- explicit out-of-scope / non-goals
- test / validation commands
- expected output branch behavior (branch/PR, no auto-merge)
- instruction to avoid secrets and `.env`
- instruction to keep changes minimal and reviewable

## Branch & Attribution

- Warren run branches use the `warren/...` prefix (`.warren/config.yaml`).
- Commit/PR attribution follows this project's convention. Do not add AI
  `Co-Authored-By` trailers unless your project wants them.
