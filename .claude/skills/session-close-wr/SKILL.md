---
name: session-close-wr
description: Close out a Warren-driven Claude Code session — capture a complete, durable handoff (git state, in-flight Warren runs, PRs, tasks, blockers), run git hygiene + report container status, clean up, and write it to memory + docs/HANDOFF.md so the next session can /clear and resume with zero drift. TRIGGER when wrapping a session, before /clear, or at a milestone.
---

# session-close-wr

Goal: make the session safely DISPOSABLE. Produce a handoff so a fresh session (reading CLAUDE.md + memory + docs/HANDOFF.md + the task list) resumes with no re-discovery. Do ALL of:

1. **Git state + hygiene (report first, act only when gated below)** —
   - `git log --oneline -5`, current branch, `git status --porcelain`; record the `main` HEAD SHA + any uncommitted work.
   - **Automated, safe (just run these):** `git fetch upstream && git fetch origin` (read-only), then `git worktree prune`.
   - **Report a hygiene table** — for each: (a) stale worktrees, (b) local branches already merged into `main`/`upstream/main` (safe-to-delete candidates), (c) branches with unpushed commits (`git log @{u}..` ahead-counts), (d) `main` divergence from `upstream/main` (ahead/behind). Read-only — surfacing, not doing.
2. **In-flight Warren runs (CRITICAL)** — for every dispatched run not yet verified+merged, record run IDs + states (GET /runs/{id}). The next session MUST resume polling/verifying these. (Token auto-loads via scripts/wr-*.sh + wr-env.sh — do NOT export by hand; jq for output.)
3. **Container status (report only — never stop)** — `docker ps --filter name=warren` + `docker stats --no-stream --no-trunc warren`; record up/down + RAM. Policy: **leave the container running** (keeps scheduled triggers / cron seeds firing). Do NOT `docker stop` at close. If it's already down, just note it.
4. **PRs** — which merged, which open/pending review.
5. **Tasks** — snapshot TaskList: completed / in_progress / pending / backlog.
6. **Blockers & GATED git-hygiene / human-action items** — anything destructive or outward-facing NEVER runs silently here; surface it as a checklist the human confirms (AskUserQuestion) or carries forward:
   - delete merged branches (only after confirming merged AND pushed)
   - merge any PR (**No-Auto-Merge rule — always human-gated**)
   - push unpushed work (outward-facing — confirm; PR base must be the fork, `--repo <you>/<repo> --base main`, never default-to-upstream)
   - `git merge upstream/main` when it is NOT a clean fast-forward (FF is fine to note as done; a real merge with conflicts is gated)
   - rate-limit reset time, "rotate Z", etc.
7. **Cleanup** — remove stale verify worktrees; stop stray background servers (dashboards/tuners) you launched. (Worktree prune + fetch already done in step 1.)
8. **Persist the handoff to BOTH**:
   - the `session-handoff` memory file (update the RESUME POINT + current state), and
   - `docs/HANDOFF.md` (commit it) — a human-readable snapshot: what's done · the single next action · in-flight runs to resume · blockers · gated hygiene items · key recipes not already in CLAUDE.md.
9. **Emit a restart message** — a ready `/clear` recommendation + a one-line "start here" (or note that `session-start-wr` will rehydrate).

## Cockpit recipes (safe to run unprompted)
- `docker ps` / `docker stats --no-stream warren` / `docker logs warren --tail 50` — status + debug (never `docker stop` at close)
- `git fetch upstream && git merge --ff-only upstream/main` — pull author updates (FF-only is safe; a non-FF merge is gated, step 6)
- `git worktree list` / `git worktree prune` — worktree hygiene

Keep it factual + scannable. Never print secrets. The split is the point: **report everything, auto-run only idempotent/local/read-only ops, gate every merge/push/delete.**
