# Phase 3 — Canopy Agent System Prompt Hardening

- **Date:** 2026-06-10
- **Status:** Complete
- **Seed:** operation-Trismegistus-4294 (plan pl-5b3d)
- **Owner:** LucraTitan (Captain)

## Problem

The four `agents/*.md` files were skeleton stubs — role name, ownership domain,
GitHub identity, and a one-line action log. Warren dispatches against these files
as agent context, so dispatched workers had no project-specific behavioral
guidance: no scoped ownership rules, no team-commit convention reference, no
quality gate, no Warren safety constraints. Behavior was inconsistent across runs.

## Hardening spec (applied to all four files)

Each `agents/*.md` now contains five sections in order:

| Section | Purpose |
|---|---|
| Header | Role name, GitHub identity + noreply email, Warren agent type |
| Ownership & file scope | What the agent owns, explicit exclusions, how to handle scope conflicts |
| Quality gate | Command (`bash -n scripts/*.sh`), terminal framing, no-success-with-red-gate rule |
| Team-commit convention | The `bun .team/team-commit.ts` invocation with any role-specific flags |
| Warren operating constraints | No git push, no secret exposure, no auto-merge, minimal changesets |

### Per-role commit flag

| Role | Flag | Reason |
|---|---|---|
| Coder-A (K-Bot-T1) | `--coder a` | Pins rotation to K-Bot-T1 when src files are staged |
| Coder-B (K-bot-T2) | `--coder b` | Pins rotation to K-bot-T2 when src files are staged |
| Auditor (K-bot-T3) | _(none)_ | Routing auto-selects auditor for test-file changesets |
| Captain (LucraTitan) | _(none)_ | Routing auto-selects captain for docs/agents changesets |

## Non-goals

- No modifications to `src/`, `scripts/`, `.warren/`, or `.team/`.
- No changes to `roster.json` or the routing logic.
- No changes to the Warren quality gate command itself.

## Acceptance criteria (from plan)

1. Each of the 4 `agents/*.md` files contains: role/scope, quality gate reference,
   team-commit convention with correct role flag, Warren constraints, ownership rules.
2. This document (`PHASE-3-DESIGN.md`) exists and documents the spec applied.
3. The phase-close gate seed (operation-Trismegistus-71be) halts for Codex review
   before any merge.
4. No PR is auto-merged.
