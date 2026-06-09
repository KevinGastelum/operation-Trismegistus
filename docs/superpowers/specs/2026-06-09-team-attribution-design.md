# Team Attribution Convention — Design Spec

- **Date:** 2026-06-09
- **Status:** Approved (design), hardened per Codex review; pending operator spec review
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
    {"role":"auditor", "globs":["**/*.test.*","**/*.spec.*","tests/**","__tests__/**","test/**","**/__snapshots__/**"]},
    {"role":"captain", "globs":["docs/**","packages/*/docs/**"]},
    {"role":"coder",   "globs":["src/**","packages/*/src/**"], "rotate":["coder-a","coder-b"]},
    {"role":"orchestrator", "globs":["**"]}
  ]
}
```

- Author email = `<id>+<login>@users.noreply.github.com`; name = `name`;
  commit subject prefix = `[label]`.
- `routes` evaluated in array order — **first match wins** (match precedence).
  `auditor`-before-`coder` is what sends `src/foo.test.ts` to the Auditor, not a
  Coder. This is the *matching* order, deliberately **decoupled** from *commit*
  order (see router step 5).
- The trailing `orchestrator` `**` route is the catch-all → every file routes
  (no orphans).
- Globs are per-project tunable (monorepo `packages/*/src|docs` and
  `__snapshots__` are already in the defaults); paths are normalized to `/`
  before matching.
- ids/logins are from the 2026-06-09 showcase; `team-init` re-verifies each via
  `gh api users/<login> --jq .id` (warn on mismatch, including login casing).

### 2. `team-commit.ts` — the router (Bun + TypeScript)

`Bun.Glob` for matching; **`Bun.spawn` argv arrays** for every git call (not
`Bun.$` — argv arrays avoid shell quoting, and with literal pathspecs stop git
from interpreting paths as options/magic). Chosen over bash+jq: operator's
stack, `bun test`-able, cross-platform (no MSYS2/jq dependency), one
self-contained file runnable from any repo. Assumes Bun on PATH (true globally,
even in non-Bun projects — it only shells out to git).

Flags: `--solo`, `--coder a|b`, `--push`, `--dry-run`, `--all`.

Default (auto-split) flow:
1. **Clean-index gate.** If the index already has staged changes
   (`git diff --cached --quiet` non-zero), abort — you curated staging on
   purpose — unless `--all` is passed. Applies to every committing mode
   (default + `--solo`); only `--dry-run`/`team-status` bypass it (they never
   mutate).
2. Collect the changeset: `git status --porcelain=v1 -z --untracked-files=all
   --renames`. Parse staged + unstaged + untracked + deleted + renamed. Route
   renames by their **new** path, and put the **old** path in that same bucket so
   the deletion half of the rename commits together. (The `-z` rename record
   emits two NUL-separated paths; pin their order with a fixture test.)
3. Empty the index without touching the working tree: `git reset -q`, or
   `git read-tree --empty` on an unborn HEAD (initial commit).
4. Bucket each changed path by route **match precedence** (first match wins),
   matching on `/`-normalized paths via `Bun.Glob`.
5. Commit buckets in **dependency order** (decoupled from match precedence):
   `orchestrator (config) → coder (src) → auditor (tests) → captain (docs)`, so
   an intermediate commit is more likely to build. For each non-empty bucket:
   - stage exactly its paths via NUL stdin (robust to spaces, globs, leading `-`):
     `git --literal-pathspecs add -A --pathspec-from-file=- --pathspec-file-nul`
   - `git commit -q --author="<name> <email>" -m "[label] <message>"`
   - the `coder` bucket's author = rotation (alternating across runs, persisted
     via `git config --local team.last-coder`) or pinned by `--coder a|b`.
6. `--push` → `git push` with existing credentials.

`--solo`: skip bucketing — a single commit authored to the **dominant** bucket's
owner (most files; ties broken by match precedence), all files staged together.
Escape hatch for keeping a feature atomic.

`--dry-run` (and `just team-status`): print the routing table (file → role →
author) and the planned commits; make **no** commits and **never** touch the
index (the safety net Codex asked for before an auto-split).

### 3. `just` recipes

- `just commit "msg" [--solo] [--coder a|b] [--push] [--all]`
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
- **Renames:** routed by the new path; old path committed in the same bucket.
- **Pre-staged / curated index (`git add -p`):** the clean-index gate aborts the
  run unless `--all` — protects intentional staging instead of silently
  flattening it to whole files.
- **Initial commit (unborn HEAD):** index emptied via `git read-tree --empty`;
  each bucket commit advances HEAD normally.
- **Submodules:** the parent repo commits only the gitlink (pointer) change;
  dirty content *inside* a submodule is the submodule's own concern. The router
  refuses to proceed when a submodule has uncommitted content, with a message.
- **Empty changeset:** no-op with a message.
- **Missing `.team/roster.json`:** error with a `team-init` hint.
- **Root-level `*.md` (README, etc.):** → Orchestrator (Captain owns `docs/**`
  only); tunable in the roster.

## Testing (`bun test`)

- Fixture: init a temp git repo; write files across all categories including a
  `src/x.test.ts` (proves auditor-beats-coder precedence), an untracked file, a
  deletion, and a rename that crosses categories.
- Assert: correct number of commits; commit **order** = config→src→tests→docs;
  each commit's author email + `[label]` prefix; A/B alternation across two
  src-only runs; rename's old+new land in one commit; `--solo` → one commit with
  the dominant author; `--dry-run` makes no commits and leaves the index
  untouched; pre-staged index aborts without `--all`; unborn-HEAD first commit
  works.
- Pure routing unit tests on the path → role function.

## Tradeoffs

Auto-split trades **atomicity** for multi-author history: a feature spanning
src + test + docs becomes 3 commits by 3 authors (the showcase goal). Reverting
such a feature reverts 3 commits, and an intermediate commit may not build
standalone (mitigated by the dependency commit order). `--solo` is the escape
hatch when a single atomic commit is wanted.

## Codex review (2026-06-09 · gpt-5.5, xhigh)

Verdict: **GO-WITH-CHANGES** — folded in above: clean-index gating (`--all`),
unborn-HEAD handling, NUL literal pathspecs, old+new rename staging, commit
order decoupled from match precedence (dependency order), `Bun.spawn` over
`Bun.$`, submodule refusal, monorepo/snapshot default globs.

Divergences (deliberate): Codex preferred multi-bucket split to be **opt-in**;
the operator chose **auto-split as the default** (mitigated by the clean-index
gate + `--dry-run`/`team-status` preview). Codex's simpler alternative — one
atomic commit to the dominant bucket plus `Co-authored-by:` trailers — does not
give the per-path **primary-author avatar** the operator wants, so it stays a
documented road-not-taken (trailers may later augment split commits).

## Non-goals (YAGNI)

- No git hook auto-stamping (the router is explicit and predictable).
- No per-bot GitHub tokens / Warren run-identity unification (separate track).
- No hunk-level attribution.
- No GUI/dashboard.

## Assumptions / open

- Bun on PATH in every target repo (true on this machine).
- Push uses the operator's existing credentials; authorship ≠ push token (verified 2026-06-09).
- Login casing exactly as recorded; `team-init` verifies via `gh`.
