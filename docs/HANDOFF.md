# HANDOFF — operation-Trismegistus

Updated: 2026-06-09 · main @ **06bbeaa** · clean, **synced to origin** · 0 in-flight Warren runs

## Start here (queued tracks — all optional, pick one)
**team-commit is shipped** (built, merged to main, pushed, GitHub-verified).
1. **Global `team-init` alias + bake `.team/` into the os-warren scaffold** so the team travels into every new project by default.
2. **Initialize Trismegistus-Dashboard history via team-commit** — `.team/` + justfile are installed but UNCOMMITTED there; `--dry-run` previewed clean (src→Coder-A, rest→Orchestrator). Safe (catch-all routes every file; no remote yet).
3. **NEW "team workflow" project** — kickoff prompt ready at `docs/team-workflow-project-kickoff.md`; create a repo + paste it into a fresh session. Build LOCALLY (Warren optional).
4. **Re-test Warren sapling/pi** — `readyz` now shows `burrow_reachable: true` (was failing); if they run now, the multi-agent roster is unblocked.
5. Global priority (time-box to 2026-06-14): **freelance-revenue-os**.

## Done this session (2026-06-09)
- **Built `team-commit`** — portable per-repo commit-attribution by changed path: routes a working tree into ONE authored commit per owner (docs→Captain, src→Coder-A/B alternating, tests→Auditor, rest→Orchestrator). Bun+TS (`Bun.Glob` + `Bun.spawn`). 15 passing tests.
  - Files: `.team/roster.json` · `.team/routing.ts` · `.team/team-commit.ts` (+ `.test.ts`) · `scripts/team-init.sh` · `justfile`.
  - Flags: `--solo` (atomic, dominant author) · `--coder a|b` · `--push` · `--dry-run` · `--all` (override clean-index gate).
  - Codex-hardened (GO-WITH-CHANGES): clean-index gate, NUL literal pathspecs, rename old+new staged together, commit order decoupled from match precedence (config→src→tests→docs), submodule refusal, monorepo/`__snapshots__` default globs.
  - Spec: `docs/superpowers/specs/2026-06-09-team-attribution-design.md` · Plan: `docs/superpowers/plans/2026-06-09-team-attribution.md`.
- **Role renames** (now the roster source of truth): LucraTitan=Captain/Coordinator · K-Bot-T1=Coder-A · K-bot-T2=Coder-B · K-bot-T3=Auditor · Kevin=Orchestrator. `agents/*.md` cards refreshed.
- **Dogfooded + verified:** the card refresh committed as `[Captain]` authored by LucraTitan; pushed; `gh api` confirms `author.login=LucraTitan`. Multi-author history works on the public repo.
- **Installed into Trismegistus-Dashboard** (preview only — uncommitted there).

## Git / Warren state
- Repo public, **main @ 06bbeaa**, clean, synced to origin/main. No open PRs; `feat/team-attribution` merged (ff) + deleted. 12 commits pushed.
- Warren healthy @ localhost:8080, **0 in-flight runs**, `WARREN_AUTO_OPEN_PR=1` live, **`burrow_reachable: true`** (changed from last session — re-test sapling/pi).

## Blockers / human-action items
- None blocking. Dashboard's first commit is your call (track #2).
- GateGuard was toggled off mid-session for the approved build, then **restored** (deleted `.claude/settings.local.json`). See memory [[gateguard-ecc]].

## Key recipes (not in CLAUDE.md)
- commit a change by team: `bun .team/team-commit.ts "msg" [--solo|--coder a|b|--push|--dry-run|--all]` · or `just commit "msg"`.
- preview routing: `bun .team/team-commit.ts --dry-run` · `just team-status`.
- install into any repo: `bash scripts/team-init.sh <target-dir>`.
- tests: `cd .team && bun test` (15).
- verify GitHub attribution: `gh api repos/KevinGastelum/operation-Trismegistus/commits/<sha> --jq .author.login`.

## Restart
`/clear` → `session-start-wr` rehydrates from CLAUDE.md + memory + this file.
Start at: **a queued track above**.
