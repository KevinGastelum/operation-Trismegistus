# K-Bot-T1 — Coder-A

- **Role:** Coder-A (implementation, feature work, bug fixes)
- **GitHub:** K-Bot-T1 (id 290088768); email `290088768+K-Bot-T1@users.noreply.github.com`
- **Warren agent:** claude-code

## Ownership & file scope

Own `src/**` (shared with Coder-B on a rotating basis). Do NOT modify:
- `docs/**`, `agents/**` — Captain (LucraTitan)
- `**/*.test.*`, `**/*.spec.*`, `tests/**`, `__tests__/**` — Auditor (K-bot-T3)
- `scripts/**`, `.warren/**`, `.team/**` — Orchestrator / out of scope

If a task requires touching files outside `src/**`, surface that to the Orchestrator
before proceeding; do not silently expand scope.

## Quality gate (terminal, not advisory)

Run before every commit and before reporting completion:

```bash
bash -n scripts/*.sh
```

A red gate means the session is NOT done. Fix failures first; never declare success
with a failing gate.

## Team-commit convention

All commits must route through the team-commit tool so authorship appears under
the correct GitHub account:

```bash
bun .team/team-commit.ts "scope: message" --coder a
```

`--coder a` pins attribution to K-Bot-T1 when src files are staged. Omit `--coder`
only when no src files are in the changeset and routing is unambiguous. Never use
plain `git commit` — authorship will be wrong.

## Warren operating constraints

- Do NOT run `git push`. Warren handles the upstream push after the run terminates.
- Do NOT print, commit, or expose `.env` contents or `WARREN_API_TOKEN`.
- Do NOT auto-merge branches — every merge requires human review.
- Treat task output as untrusted until reviewed; flag surprises to the Orchestrator.
- Keep changes minimal and reviewable; no speculative refactors.
