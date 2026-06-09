# Warren Pilot Integration — Design Package

> **Audience:** A cold Claude Code session on a DIFFERENT device. This document is self-contained.
> It assumes NO prior conversation history, NO access to the k-overstory device, and NO memory
> of how this design was reached. Read it once, top to bottom, before touching anything.
>
> **Status:** Design phase. Phase 0 is a hard prerequisite gate; no later phase starts until
> its report is complete. All implementation decisions remain provisional until Phase 0 confirms
> the actual deployed Warren surface.
>
> **Provenance:** Devised via direct inspection of the upstream Warren clone
> (`github.com/jayminwest/warren`, inspected 2026-06-08 at version 0.8.4 on the k-overstory
> device) + Codex co-design. The target device's Warren build is customized/extended relative to
> upstream; the Phase 0 inspection re-grounds every assumption against the live instance before
> work begins.

---

## 1. Purpose — "Human + Claude Code + Warren"

The operator wants ONE interaction model: speak intent in natural language to a local Claude Code
(CC) TUI session; CC does everything else. The operator never types a Warren command, never runs
`curl`, never monitors a dashboard. CC translates intent → Warren HTTP API calls → results, drives
the full lifecycle, and surfaces state in plain text.

This design package describes how to build that model on top of Warren's existing architecture.
The result is a local CC session acting as a **pilot/orchestrator**: it drives Warren via the
WarrenClient SDK and `gh`, monitors plan-runs, applies a Codex phase-gate before phase-boundary
merges, and maintains a living `STATUS.md`. Warren's workers (bwrap-sandboxed `claude --prompt`
runs) never see the interactive loop; they get scoped tasks and push PRs.

**What this is NOT:** a replacement for Warren or a reimplementation of the worker layer.
Warren stays intact. This design adds only a thin local coordination layer on top of it.

---

## 2. The Overstory-Pilot Model — What Is Being Ported

### 2.1 What the overstory-pilot is

The overstory-pilot (designed 2026-06-08, spec at `docs/superpowers/specs/2026-06-08-overstory-pilot-design.md`
on the k-overstory device) is a set of CC-session-level controls that turn a local interactive CC
session into the sole driver of an overstory-managed project. Its five components:

1. **Imperative `CLAUDE.md` contract** — rewrites the project's `CLAUDE.md` from advisory ("use
   `/ov`") to imperative ("you are the PILOT; you dispatch, never write source"). Makes pilot-mode
   the default stance a CC session adopts on read.

2. **SessionStart auto-orient hook** — on every interactive session start, emits a live orient
   (`ov status` + `sd ready` summary) plus a pilot-mode banner. Survives compaction and new
   sessions. Self-disables for headless workers (via `is_headless` check + `OVERSTORY_AGENT` env
   marker).

3. **Scoped write-gate** — a `PreToolUse` hook that mechanically blocks the lead CC session from
   writing implementation source/tests via any tool (`Edit|Write|MultiEdit|NotebookEdit` +
   Bash write-patterns). Fail-closed for code: known source dirs + code extensions in unknown
   roots are blocked; planning/config/docs roots are allowed. A `Stop`-hook dirty-diff scanner
   backstop catches anything that slips the pre-hooks. Also self-disables for headless workers.

4. **`/ov` skill — autopilot loop** — the translation layer from operator intent to the full
   `ov`/`sd`/`ml`/`cn`/`plot` command surface. Implements a state-machine autopilot: orient →
   select next ready unit → ensure spec → dispatch headless worker → monitor → on green gate:
   merge + close + record → repeat. Hard stops for human gates (capital, strategy-params,
   `LIMITS.md`). Phase-boundary protocol: consults Codex companion before phase-closing merge;
   stops if Codex is unavailable or findings are unresolved.

5. **`/session-start-ov` skill** — deeper briefing: surfaces blockers/progress/requirements,
   grills on intent, selects the right work vessel.

### 2.2 Why Warren INVERTS the model

Warren's architecture makes several of the overstory-pilot mechanisms inapplicable or unnecessary,
and replaces them with server-side equivalents:

| Overstory-pilot mechanism | Warren equivalent / inversion |
|---|---|
| Interactive CC session in the project worktree | **Pilot stays OUTSIDE Warren entirely.** Warren workers are headless-only (`claude --prompt` in bwrap sandbox). There is no interactive CC session inside Warren. |
| `PreToolUse` write-gate (CC hook system) | **Not available inside Warren.** `bwrap` STRUCTURALLY prevents writes outside the workspace (verified: `src/runs/spawn/dispatch.ts`). No CC hooks system inside a Warren run. |
| `SessionStart` orient hook | **Not available inside Warren.** No interactive sessions inside Warren runs. Context injection = system-prompt prepend at dispatch (`composeDispatchPrompt`, `src/runs/spawn/dispatch.ts:449`). |
| `ov`/`sd`/`ml`/`cn`/`plot` CLI autopilot loop | **Replaced by plan-runs.** Warren's `POST /plan-runs` coordinator (`src/plan-runs/coordinator.ts`) drives serial child dispatch, PR-merge gating, and idempotent resume server-side. |
| `ov merge` + `sd close` per seed | **Replaced by Warren reap + coordinator.** Warren reaps mulch/seeds on run completion; plan-run coordinator auto-advances on PR merge. |
| `ml record` memory accumulation | **Replaced by Warren reap/mulch.** Warren reaps `.mulch/` writes back to the project clone at run end (`src/runs/reap/mulch.ts`). |
| `OVERSTORY_AGENT` env marker for headless detection | **Not needed.** All Warren runs are headless by design; no gate bypass needed. |

**What STAYS from the pilot model:**
- The imperative `CLAUDE.md` contract for the LOCAL CC session (the pilot itself)
- The LOCAL `PreToolUse` write-gate hook (mechanical, same design as `os-eco-orchestrator-gate.sh`)
  — blocks source/test edits in the LOCAL CC session; allows planning/config/docs; self-disables
  for headless workers. bwrap replaces the write-gate INSIDE Warren workers, but the local session
  still needs the mechanical hook gate because it has the project checked out and operates with
  full CC tool access.
- The Codex phase-gate (moved to the local pilot, not inside Warren)
- The autopilot loop logic (moved to the local pilot, driving Warren via HTTP SDK instead of `ov` CLI)
- `STATUS.md` as the living state surface
- The "operator never types a command" guarantee

**What is adopted from Warren that is new to the pilot model:**
- `plan-runs` as the serialized phase executor (replaces `ov`'s autopilot within a phase)
- Event streaming (`GET /runs/:id/events?follow=1` NDJSON)
- Mid-run steering (`POST /runs/:id/steer`)
- CI-fixer (`ciFixer` config block) for automated PR repair
- Per-run preview environments (`.warren/preview.yaml`)
- Cost analytics (`GET /analytics/cost`)
- Plot integration for cross-run coordination

---

## 3. Phase 0 — Local Inspection Protocol (Hard Gate)

**This phase is a hard prerequisite.** No subsequent phase begins until the inspection report is
complete and written to a file in the project (suggested: `STATUS-phase0.md` or
`docs/warren-integration/PHASE-0-REPORT.md` in the project's local checkout). The report gates
all topology, toolchain, and API assumptions in Phases 1–7.

### 3.1 Why Phase 0 is required

The upstream Warren clone (`github.com/jayminwest/warren` v0.8.4, inspected snapshot
2026-06-08) is not archived (jayminwest/warren is live; overstory was the archived repo).
The target device runs a customized build. Any assumption about version, available
endpoints, plan-run support, auth model, conversation mode, or deployment topology that is not
re-verified against the live instance may invalidate the design. Phase 0 produces the ground truth.

### 3.2 Inspection commands — run these in order

**Step 1: Confirm Version and Liveness**

```bash
# Replace WARREN_URL and TOKEN with the actual values for this deployment.
export WARREN_URL=https://your-warren.example.com
export WARREN_TOKEN=your-bearer-token

# Liveness (auth-exempt)
curl -s "$WARREN_URL/healthz" | jq .
# Expected: {"ok":true}

# Version endpoint (auth-exempt)
curl -s "$WARREN_URL/version" | jq .
# Expected: {"version":"0.x.x"}
# Capture the version string. If the endpoint 404s, check for /api/version.

# Readiness + diagnostics (requires auth)
curl -i -H "Authorization: Bearer $WARREN_TOKEN" "$WARREN_URL/readyz"
# Distinguish: 401 = bad token (not a route issue); 404 = route absent; 200/503 = ok.
# Response shape: {"ok":bool,"checks":[...]} — NOT a bare DiagnosticCheck[] array.
# 200 = all checks ok; 503 = one or more checks failed. Note any checks[].ok:false entries.
```

**Step 2: Warren Doctor (if CLI is colocated)**

If you have SSH access to the Warren host, or if `warren`/`wr` is installed and pointed at the
deployment:

```bash
# From the Warren host or with WARREN_* env vars set:
warren doctor --no-auth 2>&1 | head -60
# or: wr doctor --no-auth

# Capture all check names and ok/fail status.
# Key checks: WARREN_API_TOKEN, CANOPY_REPO_URL, canopy_clone, bwrap,
#             burrow_reachable, db_reachable, preview_port_allocator,
#             stale_burrow_workspaces, preview_auth_strength.
```

**Step 3: Enumerate Registered Agents**

```bash
curl -s -H "Authorization: Bearer $WARREN_TOKEN" "$WARREN_URL/agents" | jq .
# List all agent names, sources (builtin vs library), versions, frontmatter.
# Verify: is claude-code registered? What is its model? Is there a canopy library override?
# Capture: agent names, their runtime IDs, model/provider values.

# Check the canopy agent detail for the primary agent you'll use:
curl -s -H "Authorization: Bearer $WARREN_TOKEN" "$WARREN_URL/agents/claude-code" | jq .
# Capture: rendered system prompt, burrow_config.network, frontmatter.model.
```

**Step 4: Enumerate Registered Projects**

```bash
curl -s -H "Authorization: Bearer $WARREN_TOKEN" "$WARREN_URL/projects" | jq '.projects[] | {id, gitUrl, localPath, hasPlot, hasSeeds, hasMulch}'
# Response shape: {"projects":[...]} — use .projects[] not .[]
# For each relevant project, capture: id, gitUrl, default branch, hasPlot, hasSeeds, hasMulch.
# Note whether the project you intend to drive has .seeds/ .mulch/ .plot/ .warren/ directories.

# Inspect the .warren/ config for the relevant project:
curl -s -H "Authorization: Bearer $WARREN_TOKEN" "$WARREN_URL/projects/{project-id}/warren-config" | jq .
# Capture: qualityGate, defaultRole, defaultModel, ciFixer.enabled, interactiveAgents,
#          plotSync.mergeStrategy, runBranchPrefix, triggers.
```

**Step 5: Verify Plan-Run Support**

```bash
# Check if POST /plan-runs is available (may 404 if this build predates plan-run support):
curl -i -X POST \
  -H "Authorization: Bearer $WARREN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project":"__probe__","planId":"__probe__","agent":"claude-code"}' \
  "$WARREN_URL/plan-runs"
# Distinguish response types carefully:
#   401          → token not accepted (auth issue, not a routing issue)
#   400 JSON     → route EXISTS; validation rejected the probe body (expected + desired)
#   404 JSON     → route exists but resource not found (app-level 404)
#   404 plain    → HTTP router has no such route; plan-run NOT available on this build
#   /api/* prefix? → try "$WARREN_URL/api/plan-runs" if plain path 404s
# Document the exact HTTP status + response body.

# If plan-runs are available, list current ones:
curl -s -H "Authorization: Bearer $WARREN_TOKEN" "$WARREN_URL/plan-runs" | jq .
```

**Step 6: Verify Event Streaming**

```bash
# If you have a recent run ID:
# curl -s -H "Authorization: Bearer $WARREN_TOKEN" \
#   "$WARREN_URL/runs/{run-id}/events?follow=0" | head -20

# List recent runs to find a run ID:
curl -s -H "Authorization: Bearer $WARREN_TOKEN" "$WARREN_URL/runs?limit=5" | jq '.runs[] | {id, state, agentName, createdAt}'
# Response shape: {"runs":[...],"total":N,"limit":N,"offset":N,"costTotalUsd":N|null} — use .runs[] not .[]
```

**Step 7: Auth Model and GitHub Token Scope**

```bash
# What GitHub token is used? What permissions does it have?
# From the Warren host environment (if accessible):
#   printenv GITHUB_TOKEN | head -c 8  # just confirm it's set, never log the full token
#   gh auth status  # if gh CLI is installed on the Warren host

# Check branch protection on the target project's main branch:
# (run this from a dev machine with gh access to the repo)
gh api repos/{owner}/{repo}/branches/main/protection 2>&1 | jq '{required_pull_request_reviews, required_status_checks}' || echo "no protection configured"

# Is auto-merge enabled on the repo?
gh api repos/{owner}/{repo} | jq '{allow_auto_merge, delete_branch_on_merge}'
```

**Step 8: CI-Fixer and Conversation Mode**

```bash
# Does the project's .warren/config.yaml have ciFixer.enabled: true?
# (captured above in Step 4, re-verify here)

# Is Leveret/conversation mode in use? Look for /conversations routes:
curl -s -H "Authorization: Bearer $WARREN_TOKEN" "$WARREN_URL/conversations" 2>&1 | head -5
# If 404: conversation mode not present or not yet enabled on this build.
# Document whether the operator is using conversation/interactive mode.
```

**Step 9: Deployment Topology and DB Backend**

```bash
# From the Warren host (or Fly.io CLI):
# fly status -a <your-warren-app>     # if on Fly
# fly vm status -a <your-warren-app>  # machine details
# fly ssh console -a <your-warren-app>   # drop into the container

# Inside the container (or on the host):
# ls -la /data/                         # volume layout
# ls -la /data/projects/                # cloned projects
# ls -la /data/burrow/                  # burrow workspaces
# ls -la /data/warren.db 2>/dev/null || echo "no sqlite (postgres?)"
# printenv WARREN_DB_URL 2>/dev/null || echo "no pg url (using sqlite)"

# DB backend:
# If WARREN_DB_URL is set → Postgres. Document the host.
# If not set → SQLite at /data/warren.db. Document backup policy (if any).
```

**Step 10: Local Checkout Discovery**

```bash
# Is there a local git checkout of the target project on THIS device (the pilot device)?
# If yes, document its path.
# If no, determine: should the pilot device clone the project? (See Phase 1.)

# Check whether the target project's .seeds/ plan exists:
# (from the local checkout or the Warren project clone path)
# ls -la /data/projects/{owner}/{repo}/.seeds/
# cat /data/projects/{owner}/{repo}/.seeds/issues.jsonl | head -5

# List seeds plan IDs (if sd is installed on the pilot device):
# sd list --json 2>/dev/null | jq '.[].id' | head -10
```

### 3.3 Phase 0 Report Template

Write the output to `docs/warren-integration/PHASE-0-REPORT.md` in the project's local checkout
(or the k-overstory repo if no local checkout yet exists). Include:

```
## Warren Instance
- Version: (from GET /version)
- Upstream diff: (is this stock upstream, or customized? list notable additions)
- Deployment: Docker/Fly/local/other
- Host: (REDACTED domain or "home server")
- Container runtime: confirmed working (from readyz + doctor output)

## Endpoints Verified
- /healthz: ok/fail
- /readyz: ok/fail + check names that failed
- /agents: list of registered agents + models
- /projects: list of relevant projects + IDs + capability flags (hasSeeds/hasPlot/hasMulch)
- /plan-runs: available (yes/no) + tested with probe request
- /runs/:id/events?follow=1: verified streaming (yes/no)
- /plots: available (yes/no)

## .warren/config.yaml (for target project, keys only — no secrets)
- qualityGate: ...
- defaultRole: ...
- defaultModel: ...
- ciFixer.enabled: ...
- interactiveAgents: ...
- plotSync.mergeStrategy: ...
- runBranchPrefix: ...

## Auth Model
- Bearer token rotation policy: ...
- GitHub token type (PAT/App): ...
- GitHub token permissions: ...
- Branch protection on main: ...
- Auto-merge enabled: ...

## Project Capabilities
- .seeds/ present: (yes/no) — list plan IDs if yes
- .mulch/ present: (yes/no)
- .plot/ present: (yes/no)
- .warren/ present: (yes/no)

## Local Checkout
- Path on pilot device: ...
- Sparse or full: ...

## DB Backend
- Type: SQLite/Postgres
- Backup policy: ...

## Conversation/Leveret Mode
- In use: (yes/no)
- Relevant to this integration: (yes/no)

## Open Questions (to resolve in Phase 1)
- (list everything Phase 0 could not confirm)
```

---

## 4. Target Topology and Concept Map

### 4.1 Target Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│  PILOT DEVICE (local, interactive)                                  │
│                                                                      │
│  CC TUI session (Claude Sonnet/Opus)                                │
│  ├── reads: CLAUDE.md (imperative pilot contract)                   │
│  ├── reads: STATUS.md (living done/in-flight/next)                  │
│  ├── reads: .seeds/ plan (via local checkout or Warren API)         │
│  ├── drives: Warren via WarrenClient HTTP SDK + gh CLI              │
│  ├── monitors: getPlanRun (poll) + streamRunEvents(childRunId) via SDK │
│  ├── consults: Codex companion (phase boundary gate)                │
│  └── writes: STATUS.md, docs/, tasks/ (planning/coordination only) │
│                                                                      │
│  Local checkout (LEAD write-gate: no src/ edits)                    │
│  ├── .seeds/          ← plan definition (must be in git)            │
│  ├── .warren/config.yaml  ← quality gate, ciFixer, defaults        │
│  ├── .mulch/          ← memory (accumulated by Warren workers)      │
│  ├── docs/            ← PRD, spec, roadmap, decisions               │
│  ├── tasks/           ← phase/task breakdowns                       │
│  └── STATUS.md        ← living state (pilot writes this)            │
│                                                                      │
│  Environment: WARREN_BASE_URL, WARREN_API_TOKEN                     │
└──────────────────────────┬──────────────────────────────────────────┘
                           │  HTTPS (WarrenClient SDK)
                           │  POST /plan-runs, GET /plan-runs/:id, GET /runs/:id/events
                           │  POST /runs/:id/steer, gh pr merge
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  WARREN SERVER (remote: Fly.io / home server / Docker)              │
│                                                                      │
│  supervisor → burrow (bwrap sandbox runtime) + warren (HTTP API)    │
│  /data/projects/{owner}/{repo}/   ← Warren's project clone          │
│  /data/burrow/                    ← bwrap workspaces per run        │
│                                                                      │
│  For each child in the plan-run:                                     │
│  ├── provisions bwrap workspace (fresh clone of project branch)     │
│  ├── seeds .canopy/ .mulch/ .seeds/ into workspace                  │
│  ├── dispatches: claude --prompt "<system> --- <task-prompt>"       │
│  ├── streams NDJSON events to pilot (GET /runs/:id/events)          │
│  ├── worker edits files, runs quality gate ($WARREN_QUALITY_GATE)   │
│  ├── commits, reaps mulch/seeds writes back, opens PR               │
│  └── plan-run coordinator polls PR merge, advances to next child    │
│                                                                      │
│  plan-runs coordinator (server-side, 10s tick):                     │
│  queued → running → [dispatch child → wait_for_run →                │
│  wait_for_merge → advance → next child] → succeeded/failed          │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Overstory-Pilot → Warren Concept Map

| Overstory-pilot concept | Warren equivalent | Notes |
|---|---|---|
| `ov sling` — dispatch headless worker | `POST /runs` via WarrenClient.dispatch() | `src/client/client.ts:195` |
| `ov status` — live state | `GET /plan-runs/:id` (poll) + `GET /runs/:id/events` (stream per child) | SDK: `getPlanRun` + `streamRunEvents(childRunId)`. Server also exposes `GET /plan-runs/:id/events` (union stream) but SDK has no client wrapper — use raw fetch if needed. |
| `ov merge` + `sd close` | Warren coordinator's PR-merge gate + auto-advance | `src/plan-runs/coordinator.ts:186–329` |
| `sd ready` — pick next seed | `planId` in `.seeds/` walked by coordinator | Plan-run reads `.seeds/issues.jsonl` |
| `ml record` — memory | Warren reap writes back `.mulch/` after each run | `src/runs/reap/mulch.ts` |
| Autopilot state machine | `POST /plan-runs` server-side coordinator | `src/plan-runs/coordinator.ts` |
| Phase-boundary Codex gate | Local pilot monitors plan-run events; consults Codex before phase-close PR merge | NOT inside Warren — lives in the local CC session |
| Worker write-gate (CC hooks) | bwrap structural isolation | `src/runs/spawn/dispatch.ts:358–398` — bwrap replaces the worker-side CC hook. LOCAL pilot write-gate is a MECHANICAL `PreToolUse` CC hook on the local checkout (not bwrap-based; see §5.7). |
| SessionStart orient | Local CC reads STATUS.md + `GET /plan-runs?project=...` | No hook available in Warren workers |
| `WARREN_QUALITY_GATE` env | `.warren/config.yaml` qualityGate → $WARREN_QUALITY_GATE in sandbox | `src/runs/spawn/dispatch.ts:417` |
| `ov doctor` | `GET /readyz` + `warren doctor` (colocated CLI) | `src/cli/commands/doctor.ts` |
| `ov costs` | `GET /analytics/cost?from=&to=&projectId=` | `src/runs/cost-analytics.ts` |
| `/session-start-ov` orient skill | Local STATUS.md read + `GET /plan-runs?project=...` | Replaced by STATUS.md + Warren API |
| Cron/trigger-based seeds | `.warren/triggers.yaml` (cron-based dispatch) | `src/warren-config/schema.ts:355–385` |

---

## 5. Strategy and Specification — The Local Pilot Layer

### 5.1 Control Surface: What the Pilot Uses

**Primary surface (WarrenClient HTTP SDK + gh):**
- `WarrenClient.fromEnv()` — reads `WARREN_BASE_URL` + `WARREN_API_TOKEN` from env
  (`src/client/client.ts:75`). Zero server-side imports; safe in any script context.
- `warren.dispatch({agent, project, prompt, seedId?, plotId?})` — spawns a single run
  (`src/client/client.ts:195`)
- `warren.createPlanRun({project, planId, agent, plotId?})` — starts the serial plan executor
  (`src/client/client.ts:471`)
- `warren.getPlanRun(planRunId)` — check progress + child runs
- `warren.listPlanRuns({project, state})` — enumerate active/failed plan-runs
- `for await (const event of warren.streamRunEvents(runId, {follow:true}))` — live stream
  (`src/client/client.ts:289`)
- `warren.steer(runId, {body, priority?})` — mid-run course correction
  (`src/client/client.ts:224`)
- `warren.waitForRun(runId, {onTick})` — poll to terminal state
- `warren.probe()` — confirm warren is reachable before beginning any phase
- `warren.listPlots({status:'active'})` / `warren.getPlot(plotId)` — Plot integration
- `gh pr merge <url> --squash --auto` / `gh pr view <url>` — PR management for phase-close merges

**Admin surface (wr/warren CLI — colocated with deployment only, not a remote client):**
- `warren doctor` — pre-flight health check (run from the Warren host or with matching env)
- `warren init --cwd <path>` — scaffold `.warren/` in a project
- `warren add-project <git-url>` — register a new project
- `warren db migrate-to-postgres` — DB admin
- `warren config migrate` — `.warren/defaults.json` → `.warren/config.yaml`

The `warren`/`wr` CLI requires access to Warren's local DB and environment. It is NOT a clean
remote client. The pilot session on a different device should use the HTTP SDK for all run/plan
operations, and SSH into the Warren host (or use Fly CLI) only for admin/doctor tasks.

**Pilot device environment variables (required):**
```bash
export WARREN_BASE_URL=https://your-warren.example.com
export WARREN_API_TOKEN=<bearer-token>
# For gh operations:
# gh auth login  (or GITHUB_TOKEN set)
```

### 5.2 Local Pilot CLAUDE.md Contract

The project's `CLAUDE.md` on the local checkout must contain an imperative pilot contract.
Below is the required content (adapt project name, project ID, and agent name):

```markdown
# PILOT CONTRACT — <Project Name>

You are the PILOT/orchestrator for this project on Warren.
Your job: translate operator intent into Warren HTTP API calls and `gh` commands. You RUN them.
You NEVER write implementation source, tests, or `.seeds/` edits directly.
You NEVER ask the operator to run a command.

## Write boundary (what the pilot may directly edit)
ALLOWED: docs/ tasks/ STATUS.md .warren/config.yaml .seeds/ (plan structure only, via sd commands
  or agreed file edits) README.md *.md (planning/coordination)
BLOCKED: src/ lib/ app/ tests/ __tests__/ e2e/ (all source and test code — dispatched to Warren)

## The autopilot loop (default behavior)
orient → confirm next phase/seed → warren.probe() → warren.createPlanRun() or warren.dispatch()
→ stream events → on phase boundary: Codex gate → merge + advance → refresh STATUS.md → repeat

## Hard stops (always pause for human)
- Capital allocation changes
- Strategy-parameter / LIMITS.md changes
- When Codex gate finds unresolved HIGH/CRITICAL issues

## Intent → action map
| Operator says | Pilot does |
|---|---|
| "build phase N" / "start phase N" | createPlanRun({project, planId:"pl-phaseN", agent}) |
| "what's happening" / "status" | listPlanRuns + getPlanRun + read STATUS.md |
| "steer the agent" / "tell it to ..." | steer(runId, {body:"..."}) |
| "ship it" / "merge phase N" | Codex gate → gh pr merge <phase-close-pr> |
| "what's next" | sd ready (local) or read STATUS.md |
| "check costs" | GET /analytics/cost?projectId=... |
| "doctor" | GET /readyz (remote) or warren doctor (if colocated) |
```

### 5.3 Autopilot Loop — State Machine

The pilot drives this loop in response to operator intent (not autonomously unless the operator
grants "go ahead and run" / "autopilot" for the session):

```
[ORIENT]
  ├── warren.probe()  ← abort if unreachable
  ├── warren.listPlanRuns({project, state:'running'})
  ├── Read STATUS.md
  └── Emit current state to operator

[SELECT PHASE]
  ├── Identify next phase from STATUS.md / tasks/
  ├── Confirm seed plan exists in .seeds/ (local or via project clone)
  └── Confirm prerequisites met (prior phase merged)

[DISPATCH PHASE]
  ├── warren.createPlanRun({project, planId, agent, plotId?})
  └── Emit: "dispatched plan-run {id} for phase N"

[MONITOR]
  ├── Poll warren.getPlanRun(planRunId) to identify the current child runId
  ├── Then stream child events: warren.streamRunEvents(childRunId, {follow:true})
  │     (The SDK exposes streamRunEvents per-run, not a streamPlanRunEvents method.
  │      The server DOES expose GET /plan-runs/:id/events as a union stream, but
  │      the SDK WarrenClient class has no wrapper for it — use raw fetch or poll+stream
  │      per child. If Phase 0 confirms a streamPlanRunEvents SDK method exists, prefer it.)
  ├── Plan-run state transitions emit: plan_run.advanced / plan_run.waiting_for_merge /
  │     plan_run.failed — surface these from getPlanRun polling or direct plan-run events
  │     endpoint (GET /plan-runs/:id/events?follow=1) via raw fetch.
  ├── On child run failure → inspect events → steer or surface to operator
  └── On plan_run.failed → surface to operator, await instruction

[PHASE-BOUNDARY GATE]  ← triggered when plan_run.waiting_for_merge fires on the
                          FINAL child of the phase (the "phase-close review" seed).
                          This seed's PR is HELD — the autopilot monitor stops here
                          and does NOT auto-merge it. The Codex gate must pass first.
  │
  │  Design: the last seed in each phase plan is a "phase-close/review" seed whose
  │  sole purpose is to trigger this gate. Its PR is opened by the worker but
  │  intentionally not auto-merged — the pilot halts when plan_run.waiting_for_merge
  │  fires on this seed's run (identified by seed type or naming convention, confirmed
  │  in Phase 0 seeds schema inspection). plan_run.succeeded is NOT the trigger —
  │  that fires AFTER the final PR merges, which is too late to gate.
  │
  ├── Get cumulative diff for the phase:
  │     gh pr list --repo <owner>/<repo> --state merged --base main \
  │       --json url,title,additions,deletions
  ├── Consult Codex: "Review the phase N diff. Flag CRITICAL/HIGH issues."
  ├── If Codex unavailable → STOP. Do not merge. Surface to operator.
  ├── If findings CRITICAL/HIGH unresolved → STOP. Surface to operator with findings.
  └── If findings clear → gh pr merge <phase-close-pr> --squash --auto → advance

[POST-MERGE]
  ├── Warren project refresh: POST /projects/:id/refresh (picks up merged .mulch/ etc.)
  ├── Refresh STATUS.md
  └── Loop to [SELECT PHASE]
```

### 5.4 Canopy Agent System-Prompt Constraints

When the operator has a custom canopy library, the system prompts for Warren workers should
include these constraints (add to the agent's `system` section in the canopy prompt):

```
Operating contract (warren-specific):
- You are a WORKER, not an orchestrator. Execute the assigned task from the seed.
- Run the quality gate ($WARREN_QUALITY_GATE, or `bun run check:all` as fallback) before
  committing. Do NOT declare success with a red gate. Fix all lint/type/test failures.
- Commit your changes. Warren handles the git push and PR opening after your run ends.
- Do NOT run `git push` yourself.
- Limit your writes to the assigned task scope. Do not refactor unrelated files.
- If you are blocked or the task is ambiguous, use `sd update --status blocked` and exit.
  Do not guess on requirements that matter.
```

These constraints are conveyed via `composeDispatchPrompt` (`src/runs/spawn/dispatch.ts:449`),
which prepends the agent's `system` section to the user prompt before dispatch. There is no CC
hooks system inside a Warren run.

### 5.5 .warren/config.yaml — Recommended Pilot Configuration

```yaml
# .warren/config.yaml
defaultRole: claude-code
defaultBranch: main
defaultModel: claude-sonnet-4-6   # adjust based on Phase 0 report
qualityGate: "<your stack's quality gate command>"
runBranchPrefix: warren

# Enable CI-fixer for automated PR repair (optional but recommended)
ciFixer:
  enabled: true
  maxRetries: 2
  cooldownMinutes: 10
  role: pr-fixer        # requires a canopy agent named pr-fixer, or omit

# Plot sync strategy (if using .plot/)
plotSync:
  mergeStrategy: auto   # or 'immediate' / 'manual'
```

### 5.6 STATUS.md — Living State

The pilot maintains `STATUS.md` at the project root. Refresh after every state transition.
Template:

```markdown
# STATUS — <Project Name>

Updated: <ISO timestamp>

## Phase
Current: Phase N — <name>
Plan-run: <plan-run-id> (state: running/succeeded/failed)

## Done
- [x] Phase 0: Inspection complete → PHASE-0-REPORT.md
- [x] Phase 1: Topology confirmed, pilot contract installed
- ...

## In Flight
- Phase N, child <seq>/<total>: seed <seed-id> → run <run-id> (state: running/pr_open)
- PR: <pr-url>

## Next
- Phase N+1: <description>
  Seeds: <seed-ids>

## Blockers
- (none) / (description + PR/run link)

## Costs (last updated <date>)
- Phase N: $X.XX (<tokens> tokens)
- Cumulative: $Y.YY

## Warren Links
- Instance: <WARREN_BASE_URL>
- Project ID: <prj_xxx>
- Plan-run: <WARREN_BASE_URL>/plan-runs/<id>
```

### 5.7 What Is Adopted vs Dropped

**Adopted from Warren (native server-side features):**
- `plan-runs` as phase executor with PR-merge gating and idempotent resume
- Event streaming for real-time monitoring
- Mid-run steering
- CI-fixer for automated PR repair
- Per-run preview environments
- Cost analytics
- Plot integration for cross-run coordination
- `$WARREN_QUALITY_GATE` env injection (via `.warren/config.yaml` `qualityGate`):
  Warren INJECTS the gate command into the sandbox env but does NOT enforce it server-side.
  Real enforcement = the worker running the gate before committing (via system-prompt
  instruction) + CI status checks on the PR + the pilot refusing to merge red PRs.
  The server has no mechanism to abort a run if the worker skips the gate.

**Dropped (not applicable in Warren):**
- Worker-side write-gate (CC `PreToolUse` hook) — bwrap handles structural isolation
- Claude Code hooks system inside Warren runs — not supported
- `ov`-style client-side autopilot loop — replaced by plan-runs coordinator
- `OVERSTORY_AGENT` env marker — not needed (all Warren runs are headless)
- `ov merge` / `sd close` per-seed in the local session — Warren reap handles seed-state
  changes the worker MADE (`.mulch/`, `.seeds/` writes back via `src/runs/reap/mulch.ts`).
  Warren does NOT close seeds on behalf of the agent; if the agent updates seed state via
  `sd update --status done`, reap propagates that write back. Seeds whose state the agent
  did not update remain unchanged.

**Kept (local pilot layer):**
- Imperative `CLAUDE.md` pilot contract (for the local CC session)
- STATUS.md as living state surface
- Codex phase-gate (local, before phase-close PR merge)
- Human gates for capital/strategy-params/LIMITS.md changes
- The "operator never types a command" guarantee
- Local write-gate: a mechanical Claude Code `PreToolUse` hook installed on the local
  checkout (same gate design as `templates/os-eco-orchestrator-gate.sh` from the
  overstory-pilot). It BLOCKS `Edit|Write|MultiEdit|NotebookEdit` tool calls and Bash
  write-patterns for source/test paths in the local CC session; allows planning, config,
  and docs paths. Emits `{"decision":"block","reason":"..."}` + exit 0 (fail-closed for
  code). Also self-disables for headless workers via `OVERSTORY_AGENT_NAME` /
  `OVERSTORY_TASK_ID` env markers. This is NOT behavioral — a behavioral instruction in
  CLAUDE.md is insufficient because it silently dissolves under compaction or a cold
  session start. The hook is the enforcement mechanism; CLAUDE.md states the intent.

---

## 6. Phases, Roadmap, and Acceptance Criteria

**Key:** Phase 0 is a hard gate. No later phase starts until Phase 0 is complete and written.
All later phase designs are provisional until Phase 0 confirms the actual Warren surface.

---

### Phase 0: Inspection and Ground Truth (HARD GATE)

**Goal:** Produce a complete, accurate picture of the deployed Warren instance before any
integration work begins. Every assumption in Phases 1–7 is provisional until this report
is written.

**Tasks:**
- [ ] Run all Phase 0 inspection commands (§3.2) against the live Warren instance
- [ ] Verify plan-run support (route available + probe request tested)
- [ ] Verify event streaming (NDJSON confirmed working)
- [ ] Capture agent registry, project IDs, capability flags
- [ ] Capture `.warren/config.yaml` for the target project
- [ ] Confirm auth model and GitHub token permissions
- [ ] Determine deployment topology (Fly/Docker/local)
- [ ] Confirm DB backend (SQLite vs Postgres)
- [ ] Determine if a local checkout exists or needs to be created
- [ ] Check `.seeds/` plan structure for the target project
- [ ] Write `PHASE-0-REPORT.md` (template in §3.3)

**Acceptance criteria:**
- `PHASE-0-REPORT.md` exists with all template sections filled
- Warren version documented
- Plan-run availability confirmed (yes/no + evidence)
- All open questions from the template listed
- No section left blank or "TBD" without an explicit note

---

### Phase 1: Topology Confirmation and Local Checkout

**Goal:** Establish the local checkout (control surface) and confirm the pilot device can drive
Warren via the HTTP SDK.

**Tasks:**
- [ ] Based on Phase 0 report, decide: full checkout or sparse (`.seeds/ .warren/ docs/ tasks/`)
- [ ] Clone or configure the local checkout (pilot device)
- [ ] Set `WARREN_BASE_URL` and `WARREN_API_TOKEN` in the pilot device's shell env
  (`.env` or `~/.zshrc`, never committed)
- [ ] Resolve WarrenClient install method (per Phase 0 Q3): copy `src/client/` from the
  Warren source, `bun link` the source checkout as `@os-eco/warren-cli`, or fall back to
  raw HTTP. Do NOT use `@os-eco/warren` — the inspected package name is `@os-eco/warren-cli`
  and publishability is unconfirmed until Phase 0. Verify `warren.probe()` succeeds.
- [ ] Confirm `gh` CLI is authenticated and has merge permissions on the target repo
- [ ] Verify the target project is registered in Warren: `warren.listProjects()`
- [ ] Run a smoke dispatch against a DISPOSABLE test repo (or a sandbox branch of the target
  project). The prompt must ask the agent to do real agent work — Warren dispatches a full
  `claude --prompt` run, not a shell command. Example prompt: "Create a file named
  `smoke-test-<timestamp>.txt` in the repo root with the content 'pilot smoke test ok'
  and commit it with message 'chore: pilot smoke test'." Verify the run streams events +
  reaches terminal state. DO NOT dispatch into a production branch — use a sandbox repo
  or a throwaway branch. If no safe target exists, skip dispatch and mark it deferred
  until Phase 3 (canopy agent hardening) is complete.
- [ ] Confirm `.seeds/` plan structure matches the Phase 0 report

**Acceptance criteria:**
- `warren.probe()` returns without error from the pilot device
- Smoke dispatch run reaches terminal state (`succeeded` or `failed` — either confirms the
  dispatch path works; a `failed` run still proves the path is live)
- Event stream received at least one event during the smoke dispatch
- `gh pr list --repo <owner>/<repo>` works from the pilot device

---

### Phase 2: Install Local Pilot Contract and Gate

**Goal:** Install the imperative `CLAUDE.md` contract, STATUS.md template, and mechanical
`PreToolUse` write-gate on the local checkout.

**Tasks:**
- [ ] Write `CLAUDE.md` pilot contract for the local checkout (§5.2 template, adapted for
  this project)
- [ ] Create `STATUS.md` (§5.6 template) and populate with current state from Phase 0 report
- [ ] Create `docs/warren-integration/PILOT-SESSION-GUIDE.md` — a one-page quick reference
  for the pilot: env setup, common intent phrases, escalation policy, Codex gate trigger
- [ ] Install the MECHANICAL write-gate: adapt `templates/os-eco-orchestrator-gate.sh` from
  the overstory-pilot design as the `PreToolUse` hook in the local checkout's
  `.claude/settings.json`. The gate MUST block `Edit|Write|MultiEdit|NotebookEdit` tool
  calls and Bash write-patterns targeting source/test paths; allow planning/config/docs;
  emit `{"decision":"block","reason":"..."}` + exit 0. Self-disable for headless workers
  via `OVERSTORY_AGENT_NAME` / `OVERSTORY_TASK_ID` env markers.
  A behavioral note in `CLAUDE.md` alone is INSUFFICIENT — it dissolves under compaction
  or cold-session start. The hook is the enforcement; `CLAUDE.md` states the contract.
- [ ] Verify the gate blocks a test Edit to `src/` and allows an Edit to `docs/`
- [ ] Commit `CLAUDE.md`, `STATUS.md`, `.claude/settings.json`,
  `docs/warren-integration/PILOT-SESSION-GUIDE.md` to the local checkout
- [ ] Push the branch and open a PR for review (operator reviews the contract)

**Acceptance criteria:**
- A cold CC session opening the local checkout and reading `CLAUDE.md` would understand
  immediately: it is a pilot, it does not write source, it uses Warren SDK
- Attempting `Edit src/anything.ts` in the CC TUI is blocked by the hook with a clear message
- `STATUS.md` accurately reflects the current project state
- All files committed and pushed

---

### Phase 3: Harden Canopy Agent System Prompts

**Goal:** Ensure Warren workers receive correct operating constraints via system-prompt injection.

**Tasks:**
- [ ] Based on Phase 0 report, determine if a custom canopy library is in use
- [ ] If canopy library: add the worker constraints from §5.4 to the relevant agent's
  `system` section in the canopy repo; push + `POST /agents/refresh` on Warren
- [ ] If using built-in `claude-code` only: verify the built-in system prompt
  (`src/registry/builtins/claude-code.ts:16–29`) covers the key constraints
  (quality gate, no manual push, git commit); note that the built-in cannot be
  overridden without a canopy library
- [ ] Verify `qualityGate` is set in `.warren/config.yaml` so `$WARREN_QUALITY_GATE` is
  injected into every sandbox (`src/runs/spawn/dispatch.ts:417`)
- [ ] Smoke test: dispatch a run with a minimal task; verify the run attempts the quality gate
  command before completing

**Acceptance criteria:**
- Worker runs receive `$WARREN_QUALITY_GATE` in their environment (confirm via event stream
  showing the gate command being run)
- Worker system prompt contains: no-manual-push, quality-gate-terminal, commit-your-changes

---

### Phase 4: Plan-Runs — Phase-Level Dispatch

**Goal:** The pilot can start a plan-run for a project phase, monitor it, and have Warren's
coordinator auto-advance through child seeds.

**Tasks:**
- [ ] Verify `.seeds/` contains a plan (plan seed with child seeds for Phase N)
- [ ] If not, create the plan — first run `sd --help` and `sd plan --help` to confirm the
  installed seeds CLI's actual subcommands and flags. The Warren synthesizer uses
  `sd create --json` + `sd plan submit <parent-id> --plan <file> --json` internally
  (see `src/plot-plan-runs/synthesizer.ts`), but this does NOT mean those are the only
  or correct user-facing commands for your seeds CLI version. Confirm the exact plan
  create/submit/show `--json` flow from `sd --help` output in Phase 0.
  Do NOT hand-edit `.seeds/*.jsonl` directly unless the schema is confirmed in Phase 0.
- [ ] Commit and push `.seeds/` plan to the project's default branch so Warren's clone
  picks it up; refresh Warren's project clone: `warren.refreshProject(PROJECT_ID)`
- [ ] Dispatch a plan-run:
  ```typescript
  const { planRun } = await warren.createPlanRun({
    project: PROJECT_ID,
    planId: "pl-phase1",
    agent: "claude-code",
  });
  ```
- [ ] Stream plan-run events and surface progress in STATUS.md:
  ```typescript
  for await (const event of warren.streamRunEvents(childRunId, {follow:true})) {
    if (event.stream === "stdout") process.stdout.write(String(event.payload));
  }
  ```
- [ ] Verify plan-run coordinator advances automatically after each child PR merges
  (default 10s tick, `src/plan-runs/config.ts:25`)
- [ ] On plan-run failure, inspect the failing child's events and surface to operator

**Acceptance criteria:**
- A plan-run with at least 2 child seeds dispatches and runs both children serially
- Coordinator waits for the first child's PR to merge before dispatching the second (verified
  by watching `plan_run.waiting_for_merge` and `plan_run.advanced` events)
- STATUS.md reflects current plan-run state throughout

---

### Phase 5: Codex Phase-Gate Before Phase-Boundary Merge

**Goal:** Before any phase-close PR merge, the pilot consults the Codex companion, resolves
findings, and only then merges. This is the one merge that is never silent.

**Tasks:**
- [ ] Design the "phase-close review" seed: the LAST seed in every phase plan is a
  lightweight review seed (e.g., `type: review`, title: "phase-close gate — do not
  auto-merge"). Its PR is opened by the Warren worker but the pilot's autopilot monitor
  STOPS at `plan_run.waiting_for_merge` for this seed rather than letting the coordinator
  auto-advance. (Confirm the seed schema in Phase 0 to know the correct type/marker field.)
- [ ] Confirm Codex companion is available on the pilot device (warm Codex pane via the
  `smux` skill or headless `codex review`)
- [ ] Implement the phase-gate protocol in the pilot session:
  1. Monitor for `plan_run.waiting_for_merge` on the phase-close seed's child run.
     The autopilot HALTS here — it does NOT merge and does NOT continue to plan_run.succeeded.
  2. Collect the phase's merged PR list:
     `gh pr list --repo <owner>/<repo> --state merged --base main --json url,title,additions,deletions --limit 20`
  3. Get cumulative diff: `gh pr diff <phase-close-pr-url>` or per-PR diffs
  4. Send to Codex: "Review this phase N diff. Flag CRITICAL/HIGH issues:
     correctness bugs, security problems, missed requirements."
  5. If Codex unavailable: STOP. Do not merge. Surface to operator.
  6. If CRITICAL/HIGH unresolved: STOP. Surface to operator with Codex findings.
  7. If clear: `gh pr merge <phase-close-pr> --squash --auto` → plan_run.succeeded fires
- [ ] Optionally add a GitHub required status check named `codex-phase-gate` (stronger
  variant): a CI job that posts a check status that the pilot sets to passing after
  Codex review. This prevents any merge without the gate running, even from the GitHub UI.
- [ ] Document the gate protocol in `PILOT-SESSION-GUIDE.md`

**Acceptance criteria:**
- One full phase-boundary executed with Codex gate: pilot HALTS at plan_run.waiting_for_merge
  on the phase-close seed, Codex findings documented in STATUS.md or a gate log, phase-close
  PR merged only after gate passes, then plan_run.succeeded fires
- If Codex is deliberately made unavailable (disconnect the pane), the pilot halts and does
  not merge

---

### Phase 6: Observability — STATUS.md + Plot Events + Warren Cost Links

**Goal:** The operator can understand project state, costs, and run history from STATUS.md and
direct Warren API calls, without ever opening the Warren UI.

**Tasks:**
- [ ] Refine STATUS.md refresh cadence: update on every plan_run.advanced,
  plan_run.failed, plan_run.succeeded, and phase-close merge event
- [ ] Add cost tracking to STATUS.md (from `GET /analytics/cost?projectId=...`):
  per-phase cost and cumulative total
- [ ] If project has `.plot/`, bind plan-runs to a Plot:
  ```typescript
  const { planRun } = await warren.createPlanRun({
    project: PROJECT_ID, planId, agent,
    plotId: PLOT_ID,   // pilot reads the active Plot from warren.listPlots()
  });
  ```
  Warren emits `run_dispatched` events to the Plot and auto-transitions `active → done`
  when the plan-run succeeds (`src/plan-runs/coordinator.ts:209`)
- [ ] Add a just recipe (or shell alias on the pilot device) for common read-outs:
  `just status` → reads STATUS.md + queries Warren API for latest plan-run state
- [ ] Verify Warren run links in STATUS.md work: `<WARREN_BASE_URL>/plan-runs/<id>`

**Acceptance criteria:**
- STATUS.md contains accurate phase, cost, and run-link data after each phase
- `GET /analytics/cost?projectId=...` returns data (confirms Warren is tracking costs)
- If Plot is in use, plan-run completion auto-transitions the Plot state

---

### Phase 7: Retrofit Existing Projects + Document Operator Intent Phrases

**Goal:** Extend the pilot contract to any existing projects already managed by Warren on this
device, and document the canonical operator vocabulary so any session can be productive.

**Tasks:**
- [ ] For each additional project: install pilot `CLAUDE.md` contract (adapted), create
  STATUS.md, confirm `.warren/config.yaml` has `qualityGate` set
- [ ] Create `docs/warren-integration/OPERATOR-VOCAB.md` — the canonical list of intent
  phrases the operator can use, each mapped to pilot actions:
  - "build phase N" / "start phase N" → createPlanRun
  - "what's happening" / "status" → STATUS.md + listPlanRuns
  - "steer the agent" / "tell it ..." → steer()
  - "ship it" / "merge phase N" → Codex gate → gh pr merge
  - "something's broken" / "fix the PR" → inspect child run events → steer or new dispatch
  - "pause" / "wait" → note in STATUS.md, no new dispatches
  - "doctor" / "is warren healthy" → GET /readyz + warren.probe()
  - "what did phase N cost" → GET /analytics/cost
  - "show me the run" → surface plan-run link + stream events
- [ ] Test the vocab document: open a fresh CC session, read only `CLAUDE.md` +
  `OPERATOR-VOCAB.md`, and confirm the session behaves correctly for three scenarios

**Acceptance criteria:**
- At least two projects have pilot contracts installed
- OPERATOR-VOCAB.md exists, committed, covers at least 10 intent phrases
- Fresh CC session test passes (documented in STATUS.md)

---

## 7. Open Questions (Phase 0 Must Resolve)

The following questions MUST be answered by the Phase 0 inspection before any Phase 1 work
begins. They represent the most likely assumptions to be violated by the target device's
customized build.

**Q1 — Plan-run availability:** Is `POST /plan-runs` implemented on this build?
The upstream v0.8.4 ships it, but the target device may be on an earlier version or a custom
branch. Phase 0 Step 5 verifies this.

**Q2 — Version and custom extensions:** What Warren version is running? What customizations
have been applied on top of upstream? Are there endpoints not in the upstream source?
Phase 0 Step 1 captures this.

**Q3 — WarrenClient distribution:** The inspected package is `@os-eco/warren-cli` (not
`@os-eco/warren`) with `"main": "src/index.ts"` (`/tmp/warren-inspect/package.json`).
`src/client/index.ts` exports `WarrenClient`, all types, config, and error classes — it is
the full SDK surface, not a thin VERSION stub. **The import path is UNRESOLVED until Phase 0
confirms the live package name and whether it is published.** Three options for the pilot:

1. **Copy `src/client/`** from the Warren source checkout into the pilot repo (zero install dep).
2. **`bun link`** the Warren source checkout so `import from "@os-eco/warren-cli"` resolves.
3. **Raw HTTP** via `fetch()` — skip the SDK entirely; use the verified route table from Phase 0.

Do NOT hard-code `@os-eco/warren` as the import — that was the old package name and may not
resolve on this build. Phase 0 must confirm before Phase 1 sets up the client.

**Q4 — Seeds plan structure:** Do the target project's `.seeds/` files follow the schema
`coordinator.ts` expects? The coordinator reads `issues.jsonl` and looks for seeds with
`extensions.planId` or a plan-type seed linking children. The exact schema is defined by the
`@os-eco/seeds` CLI (not fully visible in the Warren clone). Confirm via `sd list --json`
or direct file inspection.

**Q5 — GitHub token permissions:** Does the Warren deployment's `GITHUB_TOKEN` have
permission to push branches to the target project? Does the pilot device's `gh` have
permission to merge PRs? Branch protection settings affect whether auto-merge works or
requires direct merge.

**Q6 — Conversation/Leveret mode:** Is the target device using the Leveret conversation mode
(`mode: "conversation"` on runs)? If so, how? The design currently treats all runs as
one-shot batch runs. If conversation mode is in heavy use, the topology may need adjustment
(`src/warren-config/schema.ts:202–222`).

**Q7 — CI-fixer agent:** If `ciFixer.enabled: true` in `.warren/config.yaml`, does the
deployment have a canopy agent named `pr-fixer` (the default role, `schema.ts:270`)? If not,
CI-fixer will fail to dispatch its repair runs.

**Q8 — Deployment network access:** Can the pilot device reach the Warren API? Is there a
VPN or SSH tunnel requirement? TLS termination handled by what (Caddy/Fly edge/other)?

**Q9 — Plot availability:** Are any target projects set up with `.plot/`? If yes, is the
Plot CLI (`plot get`, `plot append`) installed on the Warren workers' sandbox? Plan-run + Plot
composition requires both (`src/plan-runs/coordinator.ts:209` + `src/runs/spawn/dispatch.ts:280`).

**Q10 — Merge policy:** Does the repo use squash merge, merge commit, or rebase? The plan-run
coordinator polls for PR merged status via GitHub API regardless of merge method, but the
phase-gate Codex review diff strategy changes depending on merge policy.

---

## 8. Provenance and Re-Grounding Note

**Devised by:** Direct inspection of the upstream Warren clone (`github.com/jayminwest/warren`,
inspected snapshot 2026-06-08, NOT archived — jayminwest/warren is live; it was overstory
that was archived) at commit tag v0.8.4 (`src/index.ts:7: VERSION = "0.8.4"`) + Codex
co-design session on the k-overstory device, 2026-06-08.

**Architecture claims in this document are cited to source file:line in the upstream clone:**
- bwrap workspace isolation: `src/runs/spawn/dispatch.ts:358–398` (`provisionBurrow`)
- Context injection = system-prompt prepend: `src/runs/spawn/dispatch.ts:449` (`composeDispatchPrompt`)
- $WARREN_QUALITY_GATE injection: `src/runs/spawn/dispatch.ts:417` (`composeRunEnv`)
- Plan-run coordinator state machine: `src/plan-runs/coordinator.ts:141–331` (`advancePlanRun`)
- Plan-run tick interval default 10s: `src/plan-runs/config.ts:25` (`DEFAULT_PLAN_RUN_TICK_MS`)
- Plan-run merge timeout default 30m: `src/plan-runs/config.ts:27` (`DEFAULT_PLAN_RUN_MERGE_TIMEOUT_MS`)
- WarrenClient SDK: `src/client/client.ts:66–542` (`WarrenClient` class); package name `@os-eco/warren-cli` (not `@os-eco/warren`)
- .warren/config.yaml schema: `src/warren-config/schema.ts:387–419` (`DefaultsConfigSchema`)
- Built-in claude-code system prompt: `src/registry/builtins/claude-code.ts:16–29`
- Doctor checks: `src/cli/commands/doctor.ts:79–120` (`runDoctor`)
- HTTP route table: README.md §HTTP API section

**CRITICAL RE-GROUNDING REQUIREMENT:** The target device runs a Warren build that is
customized/extended relative to the upstream source. Before relying on any specific endpoint,
behavior, or configuration schema described in this document, the executing CC session MUST
complete Phase 0 and verify claims against the LIVE instance. In particular:

- The plan-run coordinator may be on a different version with different behavior
- Custom endpoints may exist (or endpoints documented here may be absent)
- The `.seeds/` plan schema may differ from upstream
- The WarrenClient package may not be directly importable without a local bun-link setup

**If this document contradicts what Phase 0 finds, Phase 0 wins.**

---

*End of design package. Begin with Phase 0.*
