# Pilot Session Quick Reference

> One-page guide for a local Claude Code session driving Warren on operation-Trismegistus.
> Full design: `docs/warren-integration/WARREN-PILOT-INTEGRATION.md`
> Ground truth: `docs/warren-integration/PHASE-0-REPORT.md`
> Living state: `STATUS.md`

---

## Environment Setup

```bash
# Token auto-loads via wr-env.sh — never export by hand.
# Warren is at http://localhost:8080 (Docker, local).
# Project constants: .warren/project.json (prj_203c32jc0bqz)

# Health check (unauthenticated)
bash scripts/wr-health.sh

# List projects (authenticated)
bash scripts/wr-projects.sh

# Dispatch a single run
bash scripts/wr-run.sh claude-code prj_203c32jc0bqz "Prompt here"

# Stream events from a run
bash scripts/wr-events.sh <run-id>

# Steer a running worker
bash scripts/wr-steer.sh <run-id> "Steering message"

# Cancel a run
bash scripts/wr-cancel.sh <run-id>
```

---

## Operator Intent → Pilot Action

| Say this | Pilot does |
|---|---|
| "build phase N" / "start phase N" | `POST /plan-runs` with planId for that phase |
| "what's happening" / "status" | Read `STATUS.md` + `GET /plan-runs` for active runs |
| "steer the agent" / "tell it to ..." | `bash scripts/wr-steer.sh <run-id> "..."` |
| "ship it" / "merge phase N" | Codex gate → `gh pr merge <phase-close-pr> --squash` |
| "what's next" | `sd ready` or read `STATUS.md` |
| "something's broken" / "fix the PR" | Stream child run events → steer or new dispatch |
| "pause" / "hold" | Note in `STATUS.md`; no new dispatches |
| "doctor" / "is warren healthy" | `bash scripts/wr-health.sh` |
| "what did this cost" | `GET /analytics/cost?projectId=prj_203c32jc0bqz` |
| "show me the run" | Surface plan-run link from `STATUS.md` + stream events |
| "cancel it" | `bash scripts/wr-cancel.sh <run-id>` |

Full vocabulary: `docs/warren-integration/OPERATOR-VOCAB.md` (≥10 phrases, once written in Phase 2).

---

## Autopilot Loop (Phase Dispatch)

```
1. warren.probe()  ← abort if unreachable
2. Confirm next phase plan exists in .seeds/ (sd plan show pl-NXXX)
3. POST /plan-runs  {project, planId, agent: "claude-code"}
4. Poll GET /plan-runs/:id → identify current child runId
5. Stream child events via GET /runs/:id/events?follow=1
6. On plan_run.waiting_for_merge:
   - Non-final seed → note in STATUS.md, wait for pilot to merge PR
   - FINAL seed (phase-close gate) → HALT: run Codex gate (see below)
7. After merge → coordinator auto-advances → repeat from 4
8. On plan_run.succeeded → update STATUS.md, loop to step 1 for next phase
```

---

## Codex Phase-Gate Protocol

**Trigger:** `plan_run.waiting_for_merge` fires on the **last seed** of the phase (the "phase-close gate" seed, type marker in `.seeds/`).

**The pilot MUST NOT merge this PR automatically.** Steps:

1. Collect the phase's cumulative diff:
   ```bash
   # At plan-run launch: record the pre-phase base SHA and save it to STATUS.md
   git rev-parse main   # → <pre-phase-sha>

   # At the gate: show everything merged since the phase started
   git diff <pre-phase-sha>..HEAD

   # If you didn't record the SHA, fall back to diffing each phase PR individually:
   gh pr list --repo KevinGastelum/operation-Trismegistus \
     --state merged --base main \
     --json number,title,additions,deletions --limit 20
   gh pr diff <pr-number>   # repeat for each phase PR
   ```
2. Send to Codex companion: "Review this phase diff. Flag CRITICAL/HIGH issues: correctness bugs, security problems, missed requirements."
3. **If Codex unavailable** → STOP. Do not merge. Surface to operator.
4. **If CRITICAL/HIGH unresolved** → STOP. Surface Codex findings to operator.
5. **If findings clear** → `gh pr merge <phase-close-pr> --squash` (no `--auto`; auto-merge is OFF on this repo)
6. Record gate outcome in `STATUS.md`.

---

## Escalation Policy — Always Stop for These

- Capital allocation changes
- Strategy-parameter or `LIMITS.md` changes
- Codex gate finds unresolved CRITICAL/HIGH issues
- Codex companion is unavailable at a phase boundary
- Warren `/readyz` returns unhealthy (fix before dispatching)
- A Warren run enters `failed` state with no clear recovery path

---

## Write Boundary (What the Pilot May Edit Locally)

**Allowed:** `docs/` · `tasks/` · `STATUS.md` · `.warren/config.yaml` · `.seeds/` (plan structure via `sd` commands) · `README.md` · any `*.md` planning file

**Dispatched to Warren workers:** source code, tests, scripts, anything in `src/` / `lib/` / implementation dirs

---

## Quality Gate (for this repo)

```bash
bash -n scripts/*.sh
```

Workers run this gate (`$WARREN_QUALITY_GATE`) before committing. The pilot should verify green before merging any PR.

---

## Key Files

| File | Purpose |
|---|---|
| `STATUS.md` | Living pilot state — read at every session start |
| `CLAUDE.md` | Imperative pilot contract — governs this CC session |
| `.warren/project.json` | Project ID + Warren base URL constants |
| `.warren/config.yaml` | Quality gate, branch prefix, agent defaults |
| `.seeds/issues.jsonl` | Plan/issue queue |
| `scripts/wr-*.sh` | Warren HTTP API wrappers (bash) |
| `docs/warren-integration/PHASE-0-REPORT.md` | Ground truth from inspection |
| `docs/warren-integration/WARREN-PILOT-INTEGRATION.md` | Full design package |
