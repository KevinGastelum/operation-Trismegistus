# HANDOFF — operation-Trismegistus (Warren multi-agent pilot)

Updated: 2026-06-09 · main synced to origin (this session's final commit adds README + showcase doc + this handoff)

## Start here (single next action)
**Verify the Warren push is unblocked, then run the multi-agent showcase.**
1. Recreate Warren to load the staged `WARREN_AUTO_OPEN_PR=1`:
   `docker compose up -d` from `~/Documents/Coding/warren-kay/warren` (0 in-flight runs — safe).
2. Re-smoke to confirm the 403 is gone:
   `bash scripts/wr-run.sh claude-code prj_203c32jc0bqz "Create a file smoke2-<ts>.txt containing ok and commit it"`,
   monitor with `bash scripts/wr-events.sh <run-id>`, and confirm the reap reports **branchPushed:true + a prUrl**
   (the Phase-1 smoke FAILED here with a GitHub 403 before the PAT fix).
3. Then execute **docs/warren-integration/MULTI-AGENT-SHOWCASE.md** (the multi-agent GitHub workflow).
   Optionally also run plan-run **pl-a703** (separate track).

## Current state
- **This repo**: public git @ github.com/KevinGastelum/operation-Trismegistus, registered in Warren as
  **prj_203c32jc0bqz** (hasSeeds=true). main synced to origin.
- **Warren**: local Docker **v0.7.8** @ localhost:8080, SQLite, readyz **12/12** green. 0 in-flight runs.
- **Vision (NEW this session)**: repo reframed as a **multi-agent harness dashboard** (see `README.md`) — one
  human orchestrator drives a roster of AI agents in parallel, all observable in one place.
- **Agent roster / identity mapping**: K-bot-T1 → `planner` · K-bot-T2 → `sapling` · K-bot-T3 → `pi` ·
  LucraTitan → `claude-code` (2nd-device account) · Orchestrator → KevinGastelum (human).

## Done this session
1. **readyz 503 → 12/12**: `.warren/pr-template.md` used invalid fragment headings + `{{tokens}}` that v0.7.8
   does NOT interpolate (would emit literal `{{...}}` into PRs) → rewrote as a trailer-only override. Added
   `scripts/wr-readyz.sh` + `scripts/wr-refresh.sh`.
2. **Phase 1 COMPLETE**: smoke `run_69tpfk51w6v9` SUCCEEDED — dispatch + event-streaming proven (19 events,
   $0.06). Pre-flight green: warren.probe, gh (repo+workflow), sd 0.5.4.
3. **qualityGate set** (Q-D): `bash -n scripts/*.sh` in `.warren/config.yaml`.
4. **Seeds plan `pl-a703` authored** (Q-A, Codex-reviewed): parent `operation-Trismegistus-555f` + 3 SERIAL
   children `4b5c` (STATUS.md + PILOT-SESSION-GUIDE.md) → `99f4` (OPERATOR-VOCAB.md + `just status`) →
   `45e5` (phase-close gate). Pushed; Warren clone refreshed.
5. **README.md** (new): harness-dashboard vision. **docs/warren-integration/MULTI-AGENT-SHOWCASE.md** (new):
   next-session runbook for the multi-agent GitHub showcase.

## Blockers / human-action items
- **Warren push 403 (resolves Phase-0 Q-F) — operator FIXED 2026-06-09, NEEDS VERIFY**: Warren's container
  `GITHUB_TOKEN` is a fine-grained PAT (`github_pat_`, len 93) that lacked write to the new repo; operator added
  operation-Trismegistus (Contents + Pull requests: R/W) to it. Confirm via the re-smoke (Start here step 2).
  If still 403 → recheck the PAT's repository access + permissions. Warren git auth = `git insteadOf`
  x-access-token (warren src `supervisor/git-credentials.ts:65`).
- **`WARREN_AUTO_OPEN_PR=1` staged** in warren `.env` but NOT applied — needs the container recreate (step 1).
- **`pi` agent capability unknown** — confirm before authoring `agents/K-bot-T3.md` in the showcase.

## Open design notes
- Phase-close gate = **pilot-sole-merger** for v1 (no branch protection; repo `allow_auto_merge=false` → use
  direct `gh pr merge --squash` after review).
- Per-agent git identity = set via each run's task prompt (`git config user.name/user.email`) — see the SHOWCASE
  doc. `@warren.local` emails show as distinct commit authors but won't link to GitHub profiles.
- No `wr-plan-run.sh` yet — add one (or raw `POST /plan-runs {project, planId:"pl-a703", agent:"claude-code"}`)
  to run the plan.
- Dispatch prompts must be **ASCII-only** — em-dashes/Unicode mangle through the Windows/MSYS pipe.

## Key recipes (not already in CLAUDE.md)
- readyz detail:            `bash scripts/wr-readyz.sh`
- refresh Warren clone:     `bash scripts/wr-refresh.sh`  (run after pushing .warren/ or .seeds/ changes)
- dispatch a run:           `bash scripts/wr-run.sh claude-code prj_203c32jc0bqz "<ASCII prompt>"`
- monitor to terminal:      `bash scripts/wr-events.sh <run-id>`  (follow-streams; background it)
- single status:            `bash scripts/wr-run-status.sh <run-id>`
- Codex consult (headless): `codex exec --skip-git-repo-check "<brief>" < /dev/null`
- seeds plan:               `sd plan show pl-a703` · `sd list` · `sd ready`

## Restart
`/clear` → `session-start-wr` rehydrates from CLAUDE.md + memory + this file.
Start at: **verify push unblock (recreate Warren + re-smoke) → docs/warren-integration/MULTI-AGENT-SHOWCASE.md**.
