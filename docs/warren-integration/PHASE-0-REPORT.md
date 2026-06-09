# Warren Pilot Integration — PHASE 0 REPORT (Ground Truth)

> **Status:** Phase 0 COMPLETE. Hard-gate artifact required by `WARREN-PILOT-INTEGRATION.md` §3
> before any Phase 1+ work begins.
> **Inspected:** 2026-06-08, against the LIVE local Warren instance + the colocated server source.
> **Rule:** where this report contradicts the design package, this report wins (design §8).

---

## TL;DR — What changed vs. the design package's assumptions

| Design assumption | Reality on this device | Impact |
|---|---|---|
| Remote Warren (Fly/home server), HTTPS, raw curl + exported token | **Local Docker**, http://localhost:8080, driven by repo `scripts/wr-*.sh`; **server source colocated** at `~/Documents/Coding/warren-kay/warren` | Topology simpler. Ground-truth from source AND API. Admin = `docker exec`, not SSH/Fly. |
| Heavily customized build | **Stock v0.7.8 + 1 local commit** (mounts `~/.claude/.credentials.json` into sandboxes) | Upstream claims mostly hold; minimal drift. |
| Build is v0.8.4 (plan-runs assumed) | **v0.7.8** — but **plan-runs ARE present** (verified) | Design foundation holds. |
| Pilot drives a `.seeds/`-based plan-run phase model | Target has **NO `.seeds/`** (`hasSeeds:false`), **no `.plot/`** | **Biggest gap** — nothing for the coordinator to execute. See Q-A. |
| "The target project" (generic) | Target = **freelance-revenue-os** (`prj_cj3a8t7sdxyn`); this repo is the **unregistered pilot/control repo** | Confirm intent (Q-B). |
| Target is Bun/TS, gate `bun run check:all` | Target is **Python/uv**, gate **`uv run pytest -q`** | `qualityGate` must be set right (Q-D). |
| `gh pr merge --auto` for phase-close | Repo **`allow_auto_merge:false`**; main has **no branch protection** | Use direct `gh pr merge --squash` or enable auto-merge (Q-E). |

---

## Warren Instance

- **Version:** `0.7.8` — `GET /version` and source `src/index.ts: VERSION = "0.7.8"`.
- **Upstream diff:** `git describe` = `v0.7.8-1-g82a7711` — stock v0.7.8 **+1 local commit** (`82a7711`,
  mounts host Claude OAuth creds into sandboxes). Package `@os-eco/warren-cli` (not `@os-eco/warren`).
- **Deployment:** Docker. Container `warren` (image `warren:local`), Up, `0.0.0.0:8080->8080`. Single-container
  supervisor (burrow + warren siblings) per `docker-compose.yml`.
- **Host:** local Windows 10 + Docker. No remote/VPN/Fly. Operator drives via Git Bash + `scripts/wr-*.sh`.
- **Runtime health:** `GET /readyz` -> `ok:true`, all **12** checks green (db_reachable, burrow_reachable,
  agents, canopy_clone, canopy_clean, bwrap, warren_config, warren_config_deprecations, preview_port_allocator,
  preview_max_live, stale_burrow_workspaces, preview_auth_strength).

## Endpoints Verified

| Endpoint | Result | Evidence |
|---|---|---|
| `GET /healthz` | **ok** | `{"ok":true}` |
| `GET /readyz` (auth) | **ok**, 12/12 | see above |
| `GET /version` | ok | `{"version":"0.7.8"}` |
| `GET /agents` | 8 agents, **all source:builtin** | brainstorm, bugwatch, claude-code, nightwatch, pi, planner, **pr-fixer**, sapling |
| `GET /agents/claude-code` | builtin; model/network null via API | model not surfaced by API — see source |
| `GET /projects` | **1 project** | freelance-revenue-os / `prj_cj3a8t7sdxyn` (shape `{"projects":[...]}`) |
| `GET /projects/{id}/warren-config` | **200, all keys null** | returns DB-override (empty), NOT the in-repo file — see Q-C |
| `GET /plan-runs` | **200** `{"planRuns":[]}` | **route exists** (Q1 = YES) |
| `POST /plan-runs` (probe) | **404 app-level** | "project not found: __probe__" -> route exists, validated body |
| `GET /api/plan-runs` | 200 **but HTML** | no `/api` prefix; falls to SPA. Use bare `/plan-runs`. |
| `GET /runs?limit=5` | **200**, total:30 | recent runs all succeeded, claude-code (shape `{"runs":[...]}`) |
| `GET /runs/{id}/events?follow=0` | **200**, 130 NDJSON events | streaming verified; `{seq,kind,stream,type}` |
| `GET /plots` | **200** `{"plots":[]}` | route exists, none defined (Q9) |
| `GET /analytics/cost?projectId=` | **200** | 30 runs, **$26.14** cumulative; per-date breakdown |
| `GET /conversations` | 200 **but HTML** (SPA) | **no Leveret API** on this build (Q6 = not present) |

## Agent Registry (source-grounded)

- All 8 agents **builtin** (no custom canopy library). Override = register a same-named library agent; none here.
- **`pr-fixer` builtin EXISTS** -> ci-fixer default role satisfiable if ever enabled (Q7 = OK).
- **Builtin `claude-code`** (`src/registry/builtins/claude-code.ts`): **no model pinned** (runtime default),
  `burrow_config: network="open"`. System prompt ALREADY enforces design §5.4 worker constraints:
  quality-gate-terminal (`$WARREN_QUALITY_GATE` else CLAUDE.md/AGENTS.md else `bun run check:all`/npm),
  commit-don't-push ("Commit your changes; warren reaps... Do not run git push yourself").
  WARNING: fallback `bun run check:all` is **wrong for a Python repo**; relies on CLAUDE.md to redirect (Q-D).

## SDK / Client distribution (Q3)

- `@os-eco/warren-cli` v0.7.8; `src/client/client.ts`: `WarrenClient` (:66), `dispatch` (:195),
  `streamRunEvents` (:292, async generator), `createPlanRun` (:474). Tests present.
- **NOT installed on the pilot device** (`warren`/`wr` not on PATH; this repo has no Node project).
- **Recommendation:** keep **raw HTTP via `scripts/wr-*.sh`** as the primary surface; copy `src/client` or
  `bun link` only if a typed TS pilot is built later. Do not assume an importable npm package.

## Target `.warren/config.yaml` (in-repo file Warren dispatches against)

Identical in container clone and local checkout. Keys: `defaultRole: claude-code`, `defaultBranch: main`,
`runBranchPrefix: warren`, `defaultModel:` **commented**, `agent.pauseTimeoutMs: 1800000`,
`interactiveAgents.{brainstormRuntime,plannerRuntime}: claude-code`,
`plotSync: {mergeStrategy: manual, targetBranch: main}` — **never auto-merge**.
**`qualityGate:` ABSENT** -> `$WARREN_QUALITY_GATE` not injected (Q-D). **`ciFixer:` ABSENT** -> disabled.
`triggers.yaml`: **all commented/disabled** — no active cron (safety-clean).

## Auth Model

- **Transport:** Bearer token, resolved by `scripts/wr-env.sh` from the warren server env file (same file the
  container loads via compose `env_file`). That token is **valid** (file-derived `/readyz` -> **200**); file is
  clean UTF-8, no CRLF, single token line.
- WARNING **BUG (blocker, worked around):** a **stale `WARREN_API_TOKEN` sits in the session's inherited shell
  environment** (it 401s). `wr-env.sh` early-returns when the var is already set, so every `wr-*.sh` reuses the
  stale value -> **401**. Stale value is NOT from repo `.claude/settings*.json`, global `~/.claude/settings.json`,
  or common shell rc files — it is inherited from the launching process.
  - **Session workaround (used here):** prefix calls with `unset WARREN_API_TOKEN`; `wr-env.sh` then reloads the
    good token. Verified: unset -> `wr-projects.sh` -> 200.
  - **Permanent fix (Phase 1):** patch `wr-env.sh` to validate an already-set token against `/readyz` and reload
    from the file on rejection; or locate/remove the stale export. Never print the token.
- **GitHub token (pilot `gh`):** PAT, account KevinGastelum, scopes `gist, read:org, repo, workflow`.
  repo+workflow -> pilot can merge PRs / manage Actions (Q5 = OK).
- **Branch protection on main:** **NONE**. **Auto-merge:** **disabled** (`allow_auto_merge:false`).
  Merge methods squash/merge/rebase allowed; `delete_branch_on_merge:false`. Repo **public**; no open PRs.
- **Warren->GitHub push identity:** push host-side at reap; not separately inspected (no secret printed) — Q-F.

## Project Capabilities (freelance-revenue-os)

- `.seeds/`: **NO** (`hasSeeds:false`; absent in clone) — **design-critical gap (Q-A)**
- `.mulch/`: **NO** (absent in clone root)
- `.plot/`: **NO** (`hasPlot:false`)
- `.warren/`: **YES** (config.yaml, triggers.yaml, preview.yaml, pr-template.md, project.json)
- Type: **Python + uv** (pyproject.toml, uv.lock, config/ src/ tests/; justfile: `install: uv sync`,
  `test: uv run pytest`). Has its own `.claude/`, `CLAUDE.md`, `docs/`.

## Local Checkout (pilot device)

- **Target checkout EXISTS:** `C:\Users\Ivonne\Documents\Coding\freelance-revenue-os` — full clone.
- **Pilot/control repo:** `C:\Users\Ivonne\Documents\Coding\operation-Trismegistus` — **NOT a git repo**;
  holds the Warren integration docs, `scripts/wr-*.sh`, `.warren/` template (**empty `projectId`**), guard hook.
- `sd` (seeds CLI): **NOT installed**. `warren`/`wr` CLI: **NOT on PATH**.

## DB Backend

- **SQLite**, WAL: `/data/warren.db` (~4.7 MB) + `-wal` + `-shm`. `WARREN_DB_URL` unset (no Postgres).
- `/data/` = `burrow/` + `projects/KevinGastelum/freelance-revenue-os/` + `warren.db`.
- **Backup policy:** unknown — not observed (single-file SQLite on Docker volume `warren_data`).

## Conversation/Leveret Mode

- **Not present** (`/conversations` -> SPA). **Not relevant.** Design treats runs as one-shot batch — consistent.

---

## Resolution of the design's Open Questions (§7)

| Q | Question | Finding |
|---|---|---|
| Q1 | Plan-run availability | **YES.** GET 200; POST validates (app-404 on fake project). No `/api` prefix. |
| Q2 | Version / customizations | **v0.7.8 + 1 local commit** (OAuth creds mount). Otherwise stock. |
| Q3 | WarrenClient distribution | Source colocated; dispatch/stream/createPlanRun present. Not installed -> use raw HTTP. |
| Q4 | Seeds plan schema | **Moot — no `.seeds/` exists.** `sd` not installed. |
| Q5 | GitHub token perms | Pilot gh: repo+workflow. No branch protection. Auto-merge OFF. |
| Q6 | Conversation/Leveret | **Not present.** Not relevant. |
| Q7 | ci-fixer pr-fixer agent | **Present** (builtin). ci-fixer not enabled in target config. |
| Q8 | Pilot->Warren network | **Same host**, localhost:8080. No VPN/TLS/tunnel. |
| Q9 | Plot availability | `/plots` present; none defined; no `.plot/`. |
| Q10 | Merge policy | squash/merge/rebase allowed; auto-merge disabled; squash recommended for phase-close. |

## NEW Open Questions / Blockers for Phase 1 (resolve before building)

- **Q-A (CRITICAL): No plan to run.** Plan-run/phase model needs `.seeds/`; target has none and `sd` isn't
  installed. Decide: (a) install/author a seeds plan, (b) build phases from single `dispatch()` calls (no
  coordinator), or (c) defer plan-runs until a plan exists. Reshapes Phases 4-6.
- **Q-B: Confirm the target.** Is freelance-revenue-os the intended pilot target? (operation-Trismegistus is
  unregistered, empty projectId.) If it should be driven, it must become a git repo + be registered.
- **Q-C: warren-config endpoint semantics.** Endpoint returns null while the in-repo `.warren/config.yaml` is
  populated. Confirm Warren reads the in-repo file at dispatch (expected) vs. needing a DB override.
- **Q-D: Quality gate.** `qualityGate` unset; builtin fallback `bun run check:all` is wrong for Python. Target
  CLAUDE.md documents `uv run pytest -q` (workers can find it), but setting `qualityGate: "uv run pytest -q"`
  makes `$WARREN_QUALITY_GATE` deterministic. Recommend setting it.
- **Q-E: Phase-close merge mechanics.** `allow_auto_merge:false` => `gh pr merge --auto` fails. Enable repo
  auto-merge, or have the pilot use direct `gh pr merge --squash` after the Codex gate (no protection => direct merge works).
- **Q-F: Warren's GitHub push identity.** Confirm how Warren pushes branches host-side at reap so phase-close PRs
  attribute correctly (Kay/K-Bot-T1 per CLAUDE.md).
- **Q-G: Stale-token env fix.** Make the `wr-env.sh` validate-and-reload fix permanent so future sessions don't 401.

## Phase 0 Acceptance Criteria — CHECK

- [x] All §3.2 inspection steps run against the live instance (adapted: local Docker + `wr-*.sh`, not remote curl)
- [x] Plan-run support confirmed (route + probe) — YES
- [x] Event streaming confirmed (NDJSON, 130 events)
- [x] Agent registry, project IDs, capability flags captured
- [x] Target `.warren/config.yaml` captured (keys, no secrets)
- [x] Auth model + GitHub token perms confirmed; stale-token blocker found + worked around
- [x] Deployment topology determined (local Docker, SQLite)
- [x] DB backend confirmed (SQLite/WAL)
- [x] Local checkout determined (target checkout exists; pilot repo is non-git)
- [x] `.seeds/` structure checked — none present (key gap)
- [x] PHASE-0-REPORT.md written (this file)

---

## Evidence appendix (commands, secrets-free)

- Liveness/readiness: `bash scripts/wr-health.sh` (after `unset WARREN_API_TOKEN`); /readyz 12/12 green.
- Version: source `src/index.ts` + GET /version. Build delta: `git -C ~/Documents/Coding/warren-kay/warren describe --tags` -> `v0.7.8-1-g82a7711`.
- Projects: `bash scripts/wr-projects.sh` -> `prj_cj3a8t7sdxyn`, hasSeeds:false, hasPlot:false.
- Plan-runs: GET /plan-runs 200 `{"planRuns":[]}`; POST /plan-runs 404 "project not found: __probe__".
- Events: GET /runs/run_y906vw15k652/events?follow=0 -> 200, 130 lines.
- Cost: GET /analytics/cost?projectId=prj_cj3a8t7sdxyn -> 30 runs / $26.14.
- DB: docker exec warren -> WARREN_DB_URL unset; /data/warren.db present (WAL).
- Source: src/registry/builtins/claude-code.ts; src/client/client.ts (dispatch/stream/createPlanRun).
- gh: gh auth status; gh api repos/KevinGastelum/freelance-revenue-os[...].

*Phase 0 complete. Do not start Phase 1 until Q-A and Q-B are decided with the operator.*

---

## Resolution Update (2026-06-09)
- **Q-G RESOLVED** — stale-token root cause was a Windows **User** env var (len 66) shadowing the valid .env
  token (len 64). Deleted the User var; `wr-env.sh` hardened to treat the warren .env as canonical. Auth works
  with no `unset`.
- **Toolchain INSTALLED** — sd/cn/ml/plot/sapling (pinned to the running-warren image).
- **os-warren v2** — scaffold is now a full bootstrapper (git init + toolchain doctor + planning dirs + Warren
  registration). See `~/.os-kay/warren-scaffold/` and `docs/HANDOFF.md`.
- **This repo REGISTERED** — prj_203c32jc0bqz (public, hasSeeds=true).
- **Next** — execute Phase 1 of WARREN-PILOT-INTEGRATION.md (resolve Q-A: author a `.seeds/` plan, or use single dispatches).
