# Team Attribution Convention — Design Spec

- **Date:** 2026-06-09
- **Status:** Approved (design); pending Codex review + operator spec review
- **Owner:** Orchestrator (Kevin)

## Purpose

Route git commit **authorship** by changed file path so a five-member "team"
appears in the commit log and GitHub contributor avatars of any project:

| Category | Owner | Role |
|---|---|---|
| `docs/**` | LucraTitan | Captain / Coordinator |
| `src/**` | K-Bot-T1 / K-bot-T2 | Coder-A / Coder-B (alternating) |
| tests (`*.test.*`, `*.spec.*`, `tests/`, `__tests__/`) | K-bot-T3 | Auditor |
| everything else | KevinGastelum | Orchestrator (operator) |

Portable: one install command per repo — here (operation-Trismegistus) and the
operator's LucraTitan projects (Trismegistus-Dashboard first), and every project
going forward.

## Mechanism (why it works)

GitHub attributes a commit — and its avatar — to an account by the **author
email**. Using each account's id-based noreply email
`<id>+<login>@users.noreply.github.com` links the commit to that account
regardless of who **pushes** (the PAT / committer is irrelevant) and regardless
of the account's email-privacy setting. Verified in the 2026-06-09 showcase.

A commit has exactly **one** author, so a change spanning multiple categories is
**split into one commit per owner**. This is per-file (by path): every changed
file belongs to exactly one category, so commits add **disjoint file sets** —
nothing overlaps, so there is no merge/stash/conflict surface.

`.mailmap` is **not** sufficient: it only rewrites how authorship *displays* in
`git log`/`shortlog`; GitHub keys avatars off the real author email, which
mailmap does not change. Real per-commit author email is required.

## Components

### 1. `.team/roster.json` — single source of truth (identical per project)

```jsonc
{
  "version": 1,
  "roles": {
    "captain":      {"login":"LucraTitan",    "id":268125578, "name":"LucraTitan",      "label":"Captain"},
    "coder-a":      {"login":"K-Bot-T1",      "id":290088768, "name":"K-Bot-T1",        "label":"Coder-A"},
    "coder-b":      {"login":"K-bot-T2",      "id":292117888, "name":"K-bot-T2",        "label":"Coder-B"},
    "auditor":      {"login":"K-bot-T3",      "id":292116934, "name":"K-bot-T3",        "label":"Auditor"},
    "orchestrator": {"login":"KevinGastelum", "id":97716634,  "name":"Kevin Gastelum", "label":"Orchestrator"}
  },
  "routes": [
    {"role":"auditor", "globs":["**/*.test.*","**/*.spec.*","tests/**","__tests__/**","test/**"]},
    {"role":"captain", "globs":["docs/**"]},
    {"role":"coder",   "globs":["src/**"], "rotate":["coder-a","coder-b"]},
    {"role":"orchestrator", "globs":["**"]}
  ]
}
```

- Author email = `<id>+<login>@users.noreply.github.com`; name = `name`;
  commit subject prefix = `[label]`.
- `routes` evaluated in array order — **first match wins** (precedence). The
  `auditor`-before-`coder` order is what sends `src/foo.test.ts` to the Auditor,
  not a Coder.
- The trailing `orchestrator` `**` route is the catch-all → every file routes
  (no orphans).
- ids/logins are from the 2026-06-09 showcase; `team-init` re-verifies each via
  `gh api users/<login> --jq .id` (warn on mismatch, including login casing).

### 2. `team-commit.ts` — the router (Bun + TypeScript)

`Bun.Glob` for matching, `Bun.$` for git. Chosen over bash+jq: operator's
stack, `bun test`-able, cross-platform (no MSYS2/jq dependency), one
self-contained file runnable from any repo. Assumes Bun on PATH (true globally,
even in non-Bun projects — it only shells out to git).

Flags: `--solo`, `--coder a|b`, `--push`, `--dry-run`.

Default (auto-split) flow:
1. Collect the changeset: `git status --porcelain=v1 -z` → staged, unstaged,
   untracked, deleted, renamed (route renames by **new** path).
2. `git reset -q` — unstage everything (working tree + untracked untouched).
3. Bucket each changed path by route precedence.
4. For each non-empty bucket, in canonical order `[coder, auditor, captain, orchestrator]`:
   - `git add -A -- <bucket paths>` (covers add / modify / delete)
   - `git commit -q --author="<name> <email>" -m "[label] <message>"`
   - the `coder` bucket's author is chosen by rotation (`rotate` list, alternating
     across runs) or pinned by `--coder a|b`.
5. `--push` → `git push` with existing credentials.

`--solo`: skip bucketing — a single commit authored to the **dominant** bucket's
owner (most files; ties broken by route precedence), all files staged together.
Escape hatch for keeping a feature atomic.

`--dry-run` (and `just team-status`): print the routing table (file → role →
author) and the planned commits; make **no** commits.

### 3. `just` recipes

- `just commit "msg" [--solo] [--coder a|b] [--push]`
- `just team-status` — preview how the current working tree would route, before committing.

### 4. `team-init` — portable installer

`team-init [target-dir]` (script in `scripts/`, plus an optional global alias
mirroring the operator's `os-warren` pattern):
- copies `.team/roster.json` + `team-commit.ts` into the target repo;
- appends the `just` recipes if a justfile exists (idempotent — skip if already present);
- re-verifies roster logins/ids via `gh` (warn-only);
- prints next steps.

### 5. Refresh `agents/*.md`

Update the four role cards to the new labels (Captain / Coder-A / Coder-B /
Auditor), add the Orchestrator, and link `.team/roster.json` as the source of
truth. Keep filenames; update content only (renaming files deferred).

## Edge cases

- **Untracked files:** included, routed by path.
- **Deletions:** routed by the deleted path; staged via `git add -A`.
- **Renames:** routed by the new path.
- **Partial-hunk staging (`git add -p`):** NOT preserved — the router is
  file-granular; `git reset` flattens to whole files. Documented limitation.
- **Empty changeset:** no-op with a message.
- **Missing `.team/roster.json`:** error with a `team-init` hint.
- **Initial commit (no HEAD):** `git reset` is a no-op pre-first-commit; the
  router still stages per bucket and commits (each `git commit` advances HEAD).
- **Root-level `*.md` (README, etc.):** → Orchestrator (Captain owns `docs/**`
  only); tunable in the roster.

## Testing (`bun test`)

- Fixture: init a temp git repo; write files across all categories including a
  `src/x.test.ts` (proves auditor-beats-coder precedence), an untracked file, and
  a deletion.
- Assert: correct number of commits; each commit's author email + `[label]`
  prefix; A/B alternation across two src-only runs; `--solo` → one commit with
  the dominant author; `--dry-run` makes no commits.
- Pure routing unit tests on the path → role function.

## Tradeoffs

Auto-split trades **atomicity** for multi-author history: a feature spanning
src + test + docs becomes 3 commits by 3 authors (the showcase goal). Reverting
such a feature reverts 3 commits, and an intermediate commit may not build
standalone. `--solo` is the escape hatch when a single atomic commit is wanted.

## Non-goals (YAGNI)

- No git hook auto-stamping (the router is explicit and predictable).
- No per-bot GitHub tokens / Warren run-identity unification (separate track).
- No hunk-level attribution.
- No GUI/dashboard.

## Assumptions / open

- Bun on PATH in every target repo (true on this machine).
- Push uses the operator's existing credentials; authorship ≠ push token (verified 2026-06-09).
- Login casing exactly as recorded; `team-init` verifies via `gh`.
