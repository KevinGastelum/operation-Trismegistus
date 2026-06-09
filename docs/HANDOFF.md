# HANDOFF — operation-Trismegistus (Warren pilot)

Updated: 2026-06-09 · main HEAD 37a1a7e (pushed, clean working tree)

## Start here (single next action)
Scaffold-repair + Warren bootstrap is DONE. **Next: execute the integration plan** —
`docs/warren-integration/WARREN-PILOT-INTEGRATION.md`, beginning at **Phase 1** (Phase 0 is complete:
`docs/warren-integration/PHASE-0-REPORT.md`). Resolve its open questions first, especially **Q-A**:
the plan-run phase model needs a `.seeds/` PLAN. This repo now HAS `.seeds/` initialized but no plan yet —
either author one (`sd plan ...`) or drive phases via single `warren.dispatch()` runs.

## Current state
- **This repo**: real git repo, pushed to https://github.com/KevinGastelum/operation-Trismegistus (PUBLIC),
  registered in Warren as **prj_203c32jc0bqz** (hasSeeds=true). `.warren/project.json` carries the projectId.
  Has `.seeds/.mulch/.canopy/.warren/.claude`; LF enforced via `.gitattributes`.
- **Warren**: local Docker @ http://localhost:8080, v0.7.8, SQLite, healthy (readyz 12/12). 30 prior runs,
  **0 in-flight** (nothing to resume).
- **freelance-revenue-os** (prj_cj3a8t7sdxyn): the OLD rushed test project — user will DELETE it; reference only.

## Done this session (scaffold repair)
1. **Token bug fixed** — root cause: a stale Windows **User** env var WARREN_API_TOKEN (len 66) shadowing the
   valid `.env` token (len 64). Deleted the User var; hardened `wr-env.sh` so the warren `.env` is canonical
   (OVERRIDES any pre-set value). Auth now works with no `unset` workaround.
2. **@os-eco toolchain installed** (bun -g, pinned to the running-warren image): sd 0.5.4, cn 0.2.4, ml 0.10.6,
   plot 0.4.0, sapling 0.3.2 — on PATH via ~/.bun/bin.
3. **os-warren v2** (`~/.os-kay/warren-scaffold/os-warren.sh`, committed 596d65f) — FULL bootstrapper:
   git init -> stamp -> toolchain doctor -> planning dirs (sd/ml/cn init) -> initial commit -> outward
   (gh repo create + push + register via POST /projects + write projectId). Idempotent; confirms outward
   actions unless `--yes`; flags `--local/--no-git/--no-tools/--no-planning/--no-register/--visibility/--dry-run`.
   `os-warren.ps1` is now a THIN LAUNCHER over the `.sh` (one source of truth). Stamps a `.gitattributes` LF policy.
4. **warren/wr host shims** in ~/.bun/bin -> run the CLI inside the container (where the DB/env live; dodges the
   CRLF shebang). The @os-eco/warren-cli package is NOT on npm; host CLI = source-via-container only.
5. Templates de-token-ized (removed "export WARREN_API_TOKEN by hand" guidance).

## Codex (non-author-biased second opinion)
codex-cli 0.136.0 IS installed + authed. The warm exec-helper (codex-consult-exec.sh) is BROKEN on Windows
(`winpty: cannot start 'codex'`). USE HEADLESS: `codex exec --skip-git-repo-check "<brief>" < /dev/null`
(model gpt-5.5, read-only sandbox, approval never). Approval gate per ~/.claude/rules/common/codex-consult.md.

## Blockers / human-action items
- **Integration Q-A** (decide first): no `.seeds/` PLAN exists yet (see Start here).
- **plot-cli Windows bug**: `@os-eco/plot-cli@0.4.0 init` fails (ENOENT `.plot\...json.lock`, backslash path).
  `.plot` dropped from scaffold auto-init; create on-demand once fixed/patched.
- **warren clone CRLF**: `warren-kay/warren/src/cli/main.ts` ships a CRLF shebang -> `bun\r`; in-container `wr`
  only works via `bun run`. Enforce LF in that clone if you rebuild the Docker image.
- Phase-close merges: repo `allow_auto_merge=false` -> use direct `gh pr merge --squash` (no `--auto`).

## Key recipes (not already in CLAUDE.md)
- Scaffold a NEW project end-to-end:  `os-warren --yes --visibility public /path/to/proj`
- Local only / skip register:          `os-warren --local ...`  /  `os-warren --no-register ...`
- Codex review:                        `codex exec --skip-git-repo-check "<brief>" < /dev/null`
- Warren admin (container):            `wr doctor`  (or `docker exec warren bash -lc 'cd /app && bun run src/cli/main.ts <cmd>'`)
- Register a repo manually:            `POST /projects {gitUrl, defaultBranch}` (idempotent: GET /projects, match gitUrl first)

## Restart
Run `/clear`, then `session-start-wr` rehydrates from CLAUDE.md + memory + this file.
Start at: execute WARREN-PILOT-INTEGRATION Phase 1 (resolve Q-A/Q-B with the operator first).
