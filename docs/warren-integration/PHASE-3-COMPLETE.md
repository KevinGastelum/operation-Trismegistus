# Phase 3 Complete — Canopy Agent System Prompt Hardening

> **Status:** Phase 3 COMPLETE — gate artifact for plan pl-5b3d.
> **Date:** 2026-06-10
> **Rule:** Do not merge this PR until the pilot has reviewed the Codex findings below and confirmed the gate passes.

---

## Plan-Run Summary (pl-5b3d)

Two child seeds ran serially; each PR was merged by the pilot (no auto-merge):

| Seed | Title | PR | Outcome |
|------|-------|----|---------|
| operation-Trismegistus-4294 | Harden all 4 canopy agent system prompts and add a phase design doc | #9 | Merged ✓ |
| operation-Trismegistus-71be | Phase-close gate (this PR) | — | Pending pilot review |

## Acceptance Criteria — Verification

1. **All 4 `agents/*.md` files hardened**: Each now contains role/scope, quality gate reference (`bash -n scripts/*.sh`), team-commit convention with correct role flag, Warren constraints, and ownership/file-scope rules. ✓
2. **`docs/warren-integration/PHASE-3-DESIGN.md` exists**: Documents the hardening spec applied to all agents. ✓
3. **Phase-close gate**: This PR is the halt point. Codex review findings recorded below. **PENDING pilot confirmation before merge.**
4. **No auto-merge**: Every PR merged manually by pilot. ✓

---

## Codex Review — Cumulative Phase 3 Diff

**Diff base:** `f7f89a4` (main before Phase 3 dispatch)
**Diff head:** `618cc90` (Phase 3 implementation, merged PR #9)
**Reviewer:** Warren gate agent (operation-Trismegistus-71be)

### Files reviewed

| File | Change | Finding |
|------|--------|---------|
| `agents/K-bot-T1.md` | Stub → full system prompt (51 lines) | PASS |
| `agents/K-bot-T2.md` | Stub → full system prompt (51 lines) | PASS |
| `agents/K-bot-T3.md` | Stub → full system prompt (52 lines) | PASS |
| `agents/LucraTitan.md` | Stub → full system prompt (51 lines) | PASS |
| `docs/warren-integration/PHASE-3-DESIGN.md` | New file (50 lines) | PASS |
| `.gitignore` | Added Claude Code + runtime artifacts | PASS |

### Per-file findings

**`agents/K-bot-T1.md` (Coder-A)**
- Role, GitHub identity, and email present. ✓
- Ownership section correctly scopes to `src/**`; exclusions name all three other roles. ✓
- Quality gate section present; uses `bash -n scripts/*.sh`; framed as terminal. ✓
- Team-commit section present; correct `--coder a` flag; warns against plain `git commit`. ✓
- Warren constraints section present; no-push, no-secret, no-auto-merge all explicit. ✓
- No issues.

**`agents/K-bot-T2.md` (Coder-B)**
- Identical structure to K-bot-T1; uses `--coder b` flag. ✓
- All five sections present and correct.
- No issues.

**`agents/K-bot-T3.md` (Auditor)**
- Role scoped to test files; correct glob patterns (`**/*.test.*`, `tests/**`, etc.). ✓
- Unique addition: instruction to commit test files separately from source changes. ✓
- No `--coder` flag (routing auto-selects Auditor); correctly documented. ✓
- All five sections present and correct.
- No issues.

**`agents/LucraTitan.md` (Captain)**
- Scoped to `docs/**` and `agents/**`. ✓
- No `--coder` flag (routing auto-selects Captain); correctly documented. ✓
- All five sections present and correct.
- No issues.

**`docs/warren-integration/PHASE-3-DESIGN.md`**
- Documents the problem, hardening spec, non-goals, and acceptance criteria. ✓
- Per-role commit flag table is accurate (matches agent file contents). ✓
- No issues.

**`.gitignore`**
- Additions are all Claude Code session artifacts, Bun runtime cache, and burrow-specific paths. None are source files or secrets. ✓
- No issues.

### Summary verdict

**PASS.** All six changed files meet acceptance criteria. No scope violations (no changes to `src/`, `scripts/`, `.warren/`, or `.team/`). Quality gate exits 0. Commit attribution follows the team model (Orchestrator + Captain + Warren co-authors). No secrets or `.env` contents exposed.

---

## Pilot Instructions (do not merge until confirmed)

1. Review the Codex findings above.
2. If the review passes, merge this PR — the Phase 3 gate is clear.
3. Close seed `operation-Trismegistus-71be` and `operation-Trismegistus-eeee` after merge.

## Quality Gate

```bash
bash -n scripts/*.sh
```

Gate exit code: **0** (verified at commit time).
