# Operator Vocabulary — Warren Pilot

> Natural-language phrases the operator says → what the pilot (local Claude Code session) does.
> The operator never types a Warren command or runs `curl`; the pilot translates intent to action.
>
> Full session guide: `docs/warren-integration/PILOT-SESSION-GUIDE.md`
> Living state: `STATUS.md`

---

## Phrase Reference

| Operator says | Pilot action | Key command(s) |
|---|---|---|
| **"build phase N"** / **"start phase N"** / **"run phase N"** | Dispatches the plan-run for that phase: confirms the plan exists in `.seeds/`, POSTs to Warren, streams events, updates `STATUS.md`. | `sd plan show pl-NXXX` → `POST /plan-runs` |
| **"what's happening"** / **"status"** / **"where are we"** | Reads `STATUS.md`, queries active plan-runs, reports in-flight seeds and their run IDs. | `just status` or `cat STATUS.md` + `GET /plan-runs` |
| **"steer the agent"** / **"tell it to …"** / **"redirect the worker"** | Sends a steering message to the active child run. Pilot echoes the message and stream-confirms receipt. | `bash scripts/wr-steer.sh <run-id> "…"` |
| **"ship it"** / **"merge phase N"** / **"close the phase"** | Triggers the Codex phase-gate: diffs the phase, runs the gate protocol, and — only if clean — merges the phase-close PR. Pilot HALTS if Codex flags unresolved findings. | Codex gate → `gh pr merge <pr> --squash` |
| **"what's next"** / **"what should we do"** | Shows unblocked ready work from the issue queue. | `sd ready` |
| **"something's broken"** / **"the run failed"** / **"fix the PR"** | Streams child run events to diagnose, then either steers the live run or dispatches a new targeted run to repair the PR. | `bash scripts/wr-events.sh <run-id>` → steer or re-dispatch |
| **"pause"** / **"hold"** / **"don't dispatch anything else"** | Notes the hold in `STATUS.md` under **Blockers** and stops issuing new dispatches until the operator lifts the hold. No running runs are cancelled. | Edit `STATUS.md` |
| **"cancel it"** / **"kill the run"** / **"abort"** | Cancels the named (or currently active) run and updates `STATUS.md`. | `bash scripts/wr-cancel.sh <run-id>` |
| **"doctor"** / **"is Warren healthy"** / **"check the instance"** | Runs the health probe and reports Warren reachability, version, and any anomalies. | `bash scripts/wr-health.sh` |
| **"what did this cost"** / **"show me the spend"** | Queries the analytics endpoint and reports cumulative token + dollar cost for this project. | `GET /analytics/cost?projectId=prj_203c32jc0bqz` |
| **"show me the run"** / **"stream the logs"** / **"tail the agent"** | Surfaces the active run ID from `STATUS.md` and streams its event log in real time. | `bash scripts/wr-events.sh <run-id>` |
| **"what agents are available"** / **"list agents"** | Lists registered Warren agents (claude-code and any others). | `bash scripts/wr-agents.sh` |
| **"list runs"** / **"show recent runs"** / **"what ran"** | Lists recent runs for this project with their status and run IDs. | `bash scripts/wr-run-status.sh` |
| **"show me the PR"** / **"what PR did it open"** | Reports the PR URL opened by the active or most recent child run. Pilot finds it from the run's events or `gh pr list`. | `gh pr list --head <branch>` |
| **"start fresh"** / **"new session"** | Orients pilot: re-reads `STATUS.md`, runs `sd ready`, re-checks Warren health, and confirms no stale in-flight runs exist. | `just status` + `sd ready` + `bash scripts/wr-health.sh` |

---

## Intent Categories

### Phase Lifecycle
- **Start a phase:** "build phase N", "start phase N", "run phase N"
- **Close a phase:** "ship it", "merge phase N", "close the phase"

### Observability
- **Project state:** "what's happening", "status", "where are we"
- **Detailed run stream:** "show me the run", "stream the logs", "tail the agent"
- **Cost:** "what did this cost", "show me the spend"
- **Recent history:** "list runs", "show recent runs", "what ran"

### Control
- **Steer live worker:** "steer the agent", "tell it to …", "redirect the worker"
- **Cancel run:** "cancel it", "kill the run", "abort"
- **Hold all dispatches:** "pause", "hold", "don't dispatch anything else"

### Diagnosis & Repair
- **Infrastructure health:** "doctor", "is Warren healthy", "check the instance"
- **Broken run:** "something's broken", "the run failed", "fix the PR"

### Planning
- **Next work:** "what's next", "what should we do"
- **Session re-orient:** "start fresh", "new session"

---

## Constraints

- The pilot never auto-merges. Every merge is a deliberate pilot action after a Codex gate pass.
- The operator never runs Warren commands directly; the pilot is the sole Warren interface.
- `WARREN_API_TOKEN` is never printed, committed, or pasted — it loads via `scripts/wr-env.sh`.
- Destructive actions (project delete, worker cron triggers) require explicit human confirmation
  before the pilot proceeds.
