# Kickoff Prompt — "Team Workflow" Project

Generated 2026-06-09. Paste the fenced block below as the **first message** in a fresh
Claude Code session inside a new repo dedicated to building a portable multi-agent "team"
system. It instructs that session to spec → plan → roadmap → task → assign before coding.

## Should you use Warren to build it?

**No — build it locally; keep Warren optional.** The project is meant to work *outside*
Warren, and designing it is interactive/decision-heavy (the local spec→plan→build loop).
Warren's multi-agent edge isn't real yet: only `claude-code` runs reliably; `sapling`/`pi`
historically failed at the burrow layer. One new lead: `readyz` now shows
`burrow_reachable: true` (was failing before) — re-test sapling/pi before trusting Warren for
parallel work. Use Warren *later* for sandboxed, parallel, well-scoped implementation chunks.

## The prompt

```text
You are bootstrapping a NEW project: a portable, framework-agnostic MULTI-AGENT "TEAM"
system for my dev workflow. It must work STANDALONE in any repo (no Warren required) and
OPTIONALLY integrate with Warren (my sandboxed-agent control plane) as a pluggable backend.
Spec it, plan it, roadmap it, decompose it into tasks, and assign tasks across the team
roles — BEFORE writing implementation code.

## Who's on the team (I am the Orchestrator)
- Captain / Coordinator — LucraTitan (GitHub id 268125578) — docs, coordination, planning
- Coder-A — K-Bot-T1 (290088768) and Coder-B — K-bot-T2 (292117888) — implementation (src)
- Auditor — K-bot-T3 (292116934) — tests, review
- Orchestrator — KevinGastelum (97716634) — everything else, steering
I want a real team: defined roles, real GitHub attribution, task routing/assignment, and a
way to actually dispatch work to a teammate — usable in ANY project, and able to drive/observe
Warren when it's present.

## What ALREADY EXISTS (the seed — reuse, don't reinvent)
In my `operation-Trismegistus` repo I built `team-commit`, the ATTRIBUTION layer:
- `.team/roster.json` — single source of truth: role -> {login, id, name, label, path-globs}.
- `.team/team-commit.ts` (Bun) + `.team/routing.ts` — route a working-tree change into ONE
  authored commit per owner (docs->Captain, src->Coder-A/B alternating, tests->Auditor,
  rest->Orchestrator). Features: auto-split, --solo, --dry-run, clean-index gate, NUL
  pathspecs, dependency commit order. 15 passing Bun tests.
- `scripts/team-init.sh` — portable installer; `just commit` / `just team-status` recipes.
- KEY MECHANISM (verified, reuse it): GitHub keys a commit's avatar off the AUTHOR EMAIL
  `<id>+<login>@users.noreply.github.com`; the push token is irrelevant to authorship.
First action: read that repo's `docs/superpowers/specs/2026-06-09-team-attribution-design.md`
and its `.team/` directory to ground yourself, then install the seed here with
`bash <path-to>/operation-Trismegistus/scripts/team-init.sh .`

## What THIS project should add (brainstorm + scope; intent)
1. Team model: roles, capabilities, and how a unit of work is ASSIGNED to a teammate
   (path-based like team-commit, PLUS task-type/labels).
2. Task routing + assignment: given a task or a diff, decide the owner; reflect it in commits
   AND in issue/seed assignment.
3. Dispatch: actually hand a task to a teammate to execute — locally (Claude Code subagents)
   and via Warren (a run under that teammate's identity), with the SAME roster as the source
   of truth.
4. Attribution everywhere: commits, PRs (optional Co-authored-by), issues/seeds.
5. Standalone-first, Warren-optional: a clean interface so Warren is a pluggable backend.

## How to proceed (use my superpowers workflow — this is a hard sequence)
1. Set up issue tracking + expertise: `sd prime` / `ml prime` (scaffold them if absent),
   a justfile, and git.
2. brainstorming skill -> turn this into a DESIGN, asking me ONE question at a time on the
   real forks. HARD GATE: get my design approval before any implementation.
3. writing-plans skill -> a TDD, bite-sized implementation plan under docs/superpowers/plans/.
4. Build a ROADMAP (phases/milestones); decompose into seeds (`sd plan`), assigning each seed
   to a role.
5. Execute (subagent-driven or inline), TDD, frequent commits — and DOGFOOD team-commit for
   your own commits so the team shows up in the log from day one.
6. After planning and on any architecture call, consult a non-author-biased reviewer (Codex)
   and reconcile.

## Constraints / my conventions
- Bun + TypeScript (strict), cross-platform (Windows/MSYS2 + POSIX), Bun-native APIs.
- Reuse `team-commit` as the attribution layer; do NOT rebuild it.
- No hard Warren dependency — Warren is optional.
- Terse updates; commit messages explain WHY; NO Claude co-author trailers; no unsolicited
  refactoring; don't ask "shall I proceed?" for tasks already requested.

## First message back to me
Confirm the repo + scaffolding, install the team-commit seed, then START THE BRAINSTORM with
your first clarifying question — I suggest opening with: "what is the MINIMUM first useful
capability — attribution-only, attribution + task assignment, or attribution + dispatch?"
Begin.
```
