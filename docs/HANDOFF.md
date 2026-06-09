# HANDOFF — operation-Trismegistus (Warren multi-agent pilot)

Updated: 2026-06-09 · main @ **d6877bb** · clean, synced to origin · Warren clone synced

## Start here (single next action)
**Showcase + attribution are DONE.** Optional next tracks (pick one):
1. **Dispatch pl-a703** — serial 3-seed plan (see Backlog). Use agent `claude-code` (Warren builtins are flaky here — see Findings).
2. **Investigate sapling/pi burrow failure** so the roster bots can do genuinely distinct work.
3. **Pivot to freelance-revenue-os** — operator's stated top priority (ROI checkpoint 2026-06-14).

## Done this session
1. **Warren push 403 RESOLVED** (Phase-0 Q-F): recreated the warren container to load staged `WARREN_AUTO_OPEN_PR=1` + the PAT grant; smoke run auto-opened a PR (branchPushed:true + prUrl). Smoke PR closed, branch deleted.
2. **Multi-agent showcase COMPLETE**: `agents/{K-bot-T1,K-bot-T2,K-bot-T3,LucraTitan}.md` role cards; 4 PRs merged as KevinGastelum.
3. **Per-bot avatar attribution COMPLETE**: re-attributed all 4 card commits to real GitHub accounts via 2 clean force-push rewrites (operator-authorized). GitHub linkage API-confirmed, avatars yes. LucraTitan added as a collaborator. Contributors sidebar populates within ~24h.

## Current state
- **Repo**: public, main @ **d6877bb**, working tree clean. No open PRs; no stray `warren/*` branches.
- **Warren**: v0.7.8 @ localhost:8080, healthy, **0 in-flight runs**, `WARREN_AUTO_OPEN_PR=1` live. Project `prj_203c32jc0bqz`, clone synced to d6877bb.
- **Bot GitHub accounts** (attribution = author email `<id>+<login>@users.noreply.github.com`, NOT the push token):
  K-Bot-T1=290088768 · K-bot-T2=292117888 · K-bot-T3=292116934 · LucraTitan=268125578 · KevinGastelum=97716634.

## KEY FINDINGS (also in memory: warren-agent-reality)
- **Only `claude-code` reliably runs in this Warren env.** `planner` is plan-only (`dropped_commit`); `sapling`/`pi` fail at the burrow layer (`no_model_response`; "burrow unreachable at unix:/var/run/burrow.sock") even paced/isolated → environmental, not transient. So all 4 cards were `claude-code` fallbacks under the bot git identities; only LucraTitan=claude-code is a native match.
- **`--squash` strips commit authorship** → collapses to the merger. Use `--merge` or a force-push author rewrite to set/keep distinct authors. GitHub links a commit to an account by **author email** (id-based noreply works even with email privacy); collaborator status is NOT required for avatars on a public repo.

## Blockers / human-action items
- None blocking — all bot accounts now exist; attribution done.
- Operator preference (memory: prefer-parallel-agents): use parallel agents/subagents aggressively to speed work.

## Backlog
- **pl-a703** (serial): parent `operation-Trismegistus-555f` + 3 children `4b5c` (STATUS.md + PILOT-SESSION-GUIDE.md) → `99f4` (OPERATOR-VOCAB.md + `just status`) → `45e5` (phase-close gate). Dispatch: `POST /plan-runs {project:prj_203c32jc0bqz, planId:"pl-a703", agent:"claude-code"}` (no wr-plan-run.sh yet). Pilot merges 4b5c then 99f4; HALT at 45e5 → Codex review of cumulative diff → merge if clean.
- Optional: sapling/pi burrow-failure investigation (`docker logs warren`).

## Key recipes (not already in CLAUDE.md)
- re-attribute a commit to a bot account: rewrite author to `<id>+<login>@users.noreply.github.com` (id via `gh api users/<login> --jq .id`), then `git push --force-with-lease` (operator must authorize any main force-push).
- verify linkage: `gh api repos/KevinGastelum/operation-Trismegistus/commits/<sha> --jq .author.login`
- run status: `bash scripts/wr-run-status.sh <run-id>` — fields are TOP-LEVEL (`.state`/`.prUrl`), NOT under `.run.` (that wrapper is only on the POST /runs response).
- dispatch: `bash scripts/wr-run.sh claude-code prj_203c32jc0bqz "<ASCII prompt>"` · readyz: `bash scripts/wr-readyz.sh` · refresh clone: `bash scripts/wr-refresh.sh`
- Codex consult (headless): `codex exec --skip-git-repo-check "<brief>" < /dev/null`

## Restart
`/clear` → `session-start-wr` rehydrates from CLAUDE.md + memory + this file.
Start at: **optional pl-a703 / sapling-pi investigation / pivot to freelance-revenue-os**.
