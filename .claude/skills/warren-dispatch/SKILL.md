---
name: warren-dispatch
description: Dispatch a bounded coding task through Warren and monitor the run.
---

# Warren Dispatch

Use this skill when the user asks to send work to Warren. Commands run in bash
(MSYS2/Git Bash on Windows) from the repo root.

## Procedure

1. `bash scripts/wr-health.sh`
2. `bash scripts/wr-projects.sh`
3. `bash scripts/wr-agents.sh`
4. Identify the correct Warren project id (this repo: `<set-your-git-remote-url>`).
5. Choose the agent:
   - `claude-code` for normal implementation
   - `sapling` only if available and headless context-managed work is desired
   - other agents only when configured
6. Write a bounded prompt containing:
   - objective
   - repo context + files/directories to inspect
   - non-goals / out-of-scope
   - constraints (respect the project's safety rules in CLAUDE.md)
   - validation/test commands
   - expected branch/PR behavior (no auto-merge)
   - secret-handling warning (no `.env`, no token exposure)
7. Dispatch: `bash scripts/wr-run.sh claude-code <project-id> "<prompt>"`
8. Capture the returned run id.
9. Stream events: `bash scripts/wr-events.sh <run-id>`
10. If the run drifts: `bash scripts/wr-steer.sh <run-id> "<message>"`
11. If unsafe/incorrect: `bash scripts/wr-cancel.sh <run-id>`

## Completion Criteria

Do not report success until Warren returns a terminal successful run state or a
branch/PR is visible. Then a human reviews before merge.
