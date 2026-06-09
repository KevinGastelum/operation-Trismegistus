# CLAUDE.md

Guidance for Claude Code (and other agents) in operation-Trismegistus.

<!-- os-warren:warren-contract -->
# Warren Operating Contract

This repository interfaces with **Warren**, a self-hosted control plane for
sandboxed coding agents. Warren typically runs at `http://localhost:8080`
(Docker + UI). Use the HTTP API via `scripts/wr-*.sh` (bash; on Windows MSYS2/Git Bash) or the
Warren UI. Full detail: **docs/warren-runbook.md** and
**docs/warren-project-contract.md**.

## When to use Warren

Use Warren when work should run in an isolated sandbox and return as a branch/PR:
larger implementation tasks, risky refactors, scheduled maintenance, or tasks
benefiting from live streaming / steering / previews. Prefer local Claude Code
for small edits, inspection, and interactive debugging.

## Before a Warren dispatch

1. Read this contract and the project docs.
2. `bash scripts/wr-health.sh`
3. `bash scripts/wr-projects.sh`
4. Confirm the correct project id.
5. Check for `.seeds/`, `.mulch/`, `.plot/`, `.canopy/` and use them if present.

## Dispatch prompt requirements

objective · relevant files/dirs · constraints · explicit non-goals ·
validation/test command · branch/PR expectation (no auto-merge) · "do not expose
secrets/.env" · "keep changes minimal and reviewable".

## Safety

- Never print, commit, or paste `WARREN_API_TOKEN`; never paste `.env` contents.
- Never dispatch destructive work or enable cron triggers without explicit
  human approval.
- Never auto-merge Warren branches — review first. Treat output as untrusted
  until reviewed.

A local guard (`.claude/hooks/warren-guard.js`, wired via `.claude/settings.json`)
blocks obvious token/`.env` leaks and Warren project deletes. It fails open and
is best-effort — not a substitute for the rules above.

## Commit attribution

Agent-authored commits/branches (including Warren output) are attributed to
**Kay / K-Bot-T1**; human commits to the repo owner. Do not add Claude/AI
`Co-Authored-By` trailers. (Adjust to your own convention.)

## Useful commands

```bash
bash scripts/wr-health.sh
bash scripts/wr-projects.sh
bash scripts/wr-agents.sh
bash scripts/wr-run.sh claude-code <project-id> "Prompt here"
bash scripts/wr-events.sh <run-id>
bash scripts/wr-steer.sh <run-id> "Steering message"
bash scripts/wr-cancel.sh <run-id>
```

<!-- seeds:start -->
## Issue Tracking (Seeds)
<!-- seeds-onboard:v0.5.4 -->
<!-- seeds-onboard-schema:7 -->

This project uses [Seeds](https://github.com/jayminwest/seeds) v0.5.4 for git-native issue tracking.

**At the start of every session**, run:
```
sd prime
```

This injects session context: rules, command reference, and workflows. Pass `--format json|compact|markdown|plain|ids` on any command for agent-friendly output.

**Quick reference:**
- `sd ready` — Find unblocked work
- `sd search <query>` — Full-text search across titles + descriptions
- `sd create --title "..." --type task --priority 2` — Create issue
- `sd update <id> --status in_progress` — Claim work
- `sd close <id>` — Complete work
- `sd dep add <id> <depends-on>` — Add dependency between issues
- `sd sync` — Sync with git (run before pushing)

### Planning
Use `sd plan` when work is large or ambiguous enough that an LLM benefits from structured decomposition. Submit spawns one child seed per step; `step.blocks` uses forward semantics (step i with `blocks: [j]` means step i blocks step j, and step j gets step i's id in its `blockedBy`).

- `sd plan templates` — List built-ins (`feature`, `bug`, `refactor`) plus custom templates
- `sd plan prompt <seed-id>` — Emit a structured prompt the LLM fills in
- `sd plan submit <seed-id> --plan <file>` — Validate + spawn child seeds
- `sd plan show <pl-id>` — View sections, children, sub-plans
- `sd plan edit <id> [--name | --section <name> <text> | --step <i> --title/--priority/--type]` — In-place field edits; bumps revision
- `sd plan outcome <pl-id> --result success|partial|failure` — Record outcome (storage-only)
- `sd plan review <pl-id> --by <name>` — Record reviewer (informational)

### Before You Finish
1. Close completed issues: `sd close <id>`
2. File issues for remaining work: `sd create --title "..."`
3. Sync and push: `sd sync && git push`
<!-- seeds:end -->

<!-- mulch:start -->
## Project Expertise (Mulch)
<!-- mulch-onboard:v0.10.6 -->

This project uses [Mulch](https://github.com/jayminwest/mulch) v0.10.6 for structured expertise management.

**At the start of every session**, run:
```bash
ml prime
```

Injects project-specific conventions, patterns, decisions, failures, references, and guides into
your context. Run `ml prime --files src/foo.ts` before editing a file to load only records
relevant to that path (per-file framing, classification age, and confirmation scores included).

For monolith projects where dumping every record wastes context, set
`prime.default_mode: manifest` in `.mulch/mulch.config.yaml` (or pass `--manifest`) to emit a
quick reference + domain index. Agents then scope-load with `ml prime <domain>` or
`ml prime --files <path>`.

**Before completing your task**, record insights worth preserving — conventions discovered,
patterns applied, failures encountered, or decisions made:
```bash
ml record <domain> --type <convention|pattern|failure|decision|reference|guide> --description "..."
```

Evidence auto-populates from git (current commit + changed files). Link explicitly with
`--evidence-seeds <id>` / `--evidence-gh <id>` / `--evidence-linear <id>` / `--evidence-bead <id>`,
`--evidence-commit <sha>`, or `--relates-to <mx-id>`. Upserts of named records merge outcomes
instead of replacing them; validation failures print a copy-paste retry hint with missing fields
pre-filled.

Run `ml status` for domain health, `ml doctor` to check record integrity (add `--fix` to strip
broken file anchors), `ml --help` for the full command list. Write commands use file locking and
atomic writes, so multiple agents can record concurrently. Expertise survives `git worktree`
cleanup — `.mulch/` resolves to the main repo.

`ml prune` soft-archives stale records to `.mulch/archive/` instead of deleting them; pass
`--hard` for true deletion. Restore an archived record with `ml restore <id>`. Do not read
`.mulch/archive/` directly — those records are stale by definition. If you need historical
context, run `ml search --archived <query>`.

### Before You Finish

If you discovered conventions, patterns, decisions, or failures worth preserving during
this session, record them before closing:

```bash
ml learn                                                                    # see what files changed
ml record <domain> --type <convention|pattern|failure|decision|reference|guide> --description "..."
ml sync                                                                     # validate, stage, commit
```

Skip if no insight surfaced. Unrecorded learnings are lost; ritual filler records are also noise.
<!-- mulch:end -->
