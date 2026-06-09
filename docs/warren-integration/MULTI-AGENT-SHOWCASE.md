# Multi-Agent Showcase — Next-Session Runbook

Goal: make this GitHub repo visibly reflect coordinated multi-agent work. Each
Warren agent identity should land at least one **visible commit/PR** in
`operation-Trismegistus`, so the repo's commit history + contributors list shows
"each bot did something" — a reference pattern for tying together work from
multiple agents.

## Environment (constants)

- Warren: local Docker **v0.7.8** @ `http://localhost:8080`
- Project id: **`prj_203c32jc0bqz`**
- Driver scripts: `scripts/wr-*.sh` (`wr-run.sh`, `wr-events.sh`,
  `wr-run-status.sh`, `wr-refresh.sh`, `wr-readyz.sh`, …)
- Builtin Warren agents in play: `planner`, `sapling`, `pi`, `claude-code`
  (Phase 0 found **no custom canopy library** — all 8 agents are builtin)

## Agent → Identity mapping (document this prominently)

| Bot name      | Warren agent  | Role / capability                         | Git identity used to commit              |
| :------------ | :------------ | :---------------------------------------- | :--------------------------------------- |
| **K-bot-T1**  | `planner`     | Planning / decomposition                  | `K-bot-T1` · `k-bot-t1@warren.local`     |
| **K-bot-T2**  | `sapling`     | VCS / stacked-diffs                       | `K-bot-T2` · `k-bot-t2@warren.local`     |
| **K-bot-T3**  | `pi`          | (capability TBD — confirm, see step 2)    | `K-bot-T3` · `k-bot-t3@warren.local`     |
| **LucraTitan**| `claude-code` | General coding (operator's 2nd-device acct)| `LucraTitan` · `lucratitan@warren.local` |
| **Orchestrator** | — (human)  | Reviews + merges every PR                 | `KevinGastelum` (human)                  |

Notes:
- K-bot-T2 (sapling) and K-bot-T3 (pi) bot identities are **not yet created** —
  they get created implicitly the first time a run commits under that git
  name/email (see step 3).
- LucraTitan is the operator's second-device account mapped to the `claude-code`
  agent.

---

## RUNBOOK (numbered)

### 1) PREREQ — verify Warren push is unblocked

Background: Warren's container `GITHUB_TOKEN` is a **fine-grained PAT**. The
operator just added `operation-Trismegistus` to that PAT's repository access with
**Contents: Read/write** and **Pull requests: Read/write**. Separately,
`WARREN_AUTO_OPEN_PR=1` was **staged in the warren `.env` but not yet applied**
(container hasn't been recreated since).

Steps:

1. Recreate the Warren container so it loads the new env (`WARREN_AUTO_OPEN_PR=1`
   + refreshed token). Run from the warren repo, **not** this one:
   ```bash
   cd ~/Documents/Coding/warren-kay/warren
   docker compose up -d        # recreates containers picking up the new .env
   ```
2. Wait for readiness, then confirm health:
   ```bash
   bash scripts/wr-readyz.sh
   bash scripts/wr-health.sh
   ```
3. Smoke dispatch a trivial commit-producing task:
   ```bash
   bash scripts/wr-run.sh claude-code prj_203c32jc0bqz \
     "Create a file smoke-warren-push.txt containing the current UTC timestamp, then commit it. Set git user.name='LucraTitan' and user.email='lucratitan@warren.local' before committing."
   ```
4. Monitor:
   ```bash
   bash scripts/wr-events.sh <run-id>
   bash scripts/wr-run-status.sh <run-id>
   ```
5. **CONFIRM the reap reports `branchPushed: true` AND a `prUrl`** (i.e. a PR was
   opened — proves both push perms and `WARREN_AUTO_OPEN_PR=1` are live).

If still **403 / push rejected**: the PAT grant didn't apply. Recheck on GitHub
that the fine-grained PAT lists `operation-Trismegistus` under *Repository
access* with **Contents R/W + Pull requests R/W**, then recreate the container
again. Do **not** proceed to the showcase until a smoke PR opens cleanly.

> The smoke artifact (`smoke-warren-push.txt`) is throwaway — close/decline its PR
> or delete the file after; it is not part of the showcase deliverable.

### 2) SHOWCASE — one run per agent, each a visible commit/PR

Deliverable: an **`agents/`** directory at the repo root containing one
**role-card markdown per bot**:

```
agents/
  K-bot-T1.md     # committed by planner / K-bot-T1
  K-bot-T2.md     # committed by sapling / K-bot-T2
  K-bot-T3.md     # committed by pi      / K-bot-T3
  LucraTitan.md   # committed by claude-code / LucraTitan
```

Each role card contains:
- **Bot name** (e.g. K-bot-T1)
- **Warren agent** it maps to (e.g. `planner`)
- **Role / capability** (planner = planning; sapling = VCS / stacked-diffs;
  pi = ? — confirm pi's actual capability during this session and fill it in;
  claude-code = general coding)
- A one-line **dated "first action" log entry**, e.g.
  `2026-06-09 — first action: authored my own role card via Warren run <run-id>.`

Each card is committed **by that bot's own git identity** (see step 3) so GitHub
attributes the commit to the right bot.

Dispatch one run per agent. Example for K-bot-T1 (planner) — adapt the strings
per bot:

```bash
bash scripts/wr-run.sh planner prj_203c32jc0bqz \
  "Create file agents/K-bot-T1.md — a role card with: Bot name 'K-bot-T1'; Warren agent 'planner'; Role 'planning / decomposition'; and a dated first-action log line for $(date -u +%Y-%m-%d). Before committing, run: git config user.name 'K-bot-T1' && git config user.email 'k-bot-t1@warren.local'. Keep it to a single small markdown file. Do not touch any other file. Push a branch and open a PR; do not merge."
```

Repeat with the per-bot substitutions:

| Run | agent         | file              | git user.name | git user.email             |
| :-- | :------------ | :---------------- | :------------ | :------------------------- |
| A   | `planner`     | `agents/K-bot-T1.md`   | `K-bot-T1`   | `k-bot-t1@warren.local`   |
| B   | `sapling`     | `agents/K-bot-T2.md`   | `K-bot-T2`   | `k-bot-t2@warren.local`   |
| C   | `pi`          | `agents/K-bot-T3.md`   | `K-bot-T3`   | `k-bot-t3@warren.local`   |
| D   | `claude-code` | `agents/LucraTitan.md` | `LucraTitan` | `lucratitan@warren.local` |

Each run should: write only its one file, push a branch, open a PR, **not merge**.

### 3) KEY MECHANIC — distinct git author identity per run

The problem to solve + document: make each Warren run commit with a **distinct
git author (name + email)** so GitHub attributes each bot separately (separate
contributor entries).

**Working method (use this):** instruct each run's task **prompt** to set the git
identity inside the sandbox before committing:

```bash
git config user.name '<BotName>' && git config user.email '<bot>@warren.local'
```

This is exactly what the Phase-1 smoke test confirmed works — the `claude-code`
worker self-ran `git config user.name "K-Bot-T1" && git config user.email
"k-bot-t1@warren.local"` inside the sandbox before committing, and the commit was
attributed accordingly. Per-prompt git config is therefore the documented,
known-good path.

**OPEN QUESTION (to resolve, don't block on):** confirm whether Warren / canopy
can configure a cleaner **per-agent identity** (e.g. a canopy agent field that
pins author name+email) instead of repeating it in every prompt. Because Phase 0
found **no custom canopy library** (all 8 agents builtin), there is no per-agent
identity hook today — so per-prompt git config is the pragmatic path for the
pilot. Revisit if/when a custom canopy library is introduced.

> GitHub linkage caveat: a commit shows as a *linked* contributor only if its
> author email matches a GitHub account. The `@warren.local` emails will show as
> **distinct named authors** in `git log` / the commit list (which satisfies the
> showcase: "each bot did something"), but won't link to real GitHub profiles.
> If true linked-avatar attribution is wanted later, use per-bot
> GitHub-registered emails instead — note this as a possible follow-up, not a
> blocker.

### 4) ORCHESTRATOR ROLE — KevinGastelum reviews + merges

KevinGastelum (the human) is the **sole merger** for the pilot. The repo has
`allow_auto_merge=false` and **no branch protection**, so merge each bot's PR
manually after review:

```bash
gh pr list
gh pr view <pr-number>          # review the diff
gh pr merge <pr-number> --squash
```

Result: GitHub shows the **bots' commits as distinct authors/contributors** plus
**Kevin's merge commits** — demonstrating coordinated multi-agent work with a
human in the loop.

### 5) PARALLELISM — pace, don't flood

The operator wants parallel work to go faster. Constraint: **all Warren runs
share the user's single Claude rate limit**, so don't fire all 4 at once if it
risks throttling. But the pilot **can dispatch + monitor multiple runs
concurrently**, and these four runs are **independent** (no ordering dependency —
each writes a different file), unlike the serial `pl-a703` plan-run.

Suggested cadence — **2 small waves**:
- **Wave 1:** runs A (`planner`) + B (`sapling`) — dispatch, monitor to
  branch-pushed / PR-opened.
- **Wave 2:** runs C (`pi`) + D (`claude-code`) — dispatch after Wave 1 settles.

Merge PRs (step 4) as they land; merges have no ordering constraint either.

### 6) RELATION TO pl-a703 — separate track

The existing serial plan **`pl-a703`** (3 seeds building `STATUS.md` /
`OPERATOR-VOCAB.md` / a phase-close gate) is a **separate track** with its own
internal ordering. This showcase is independent and can run **before or after**
pl-a703. **Do not conflate them** — different goals, different files, different
sequencing.

---

## Definition of done

- `agents/` directory exists at repo root with **4 role cards**
  (`K-bot-T1.md`, `K-bot-T2.md`, `K-bot-T3.md`, `LucraTitan.md`).
- Each card was **committed by a distinct bot git identity** (planner/K-bot-T1,
  sapling/K-bot-T2, pi/K-bot-T3, claude-code/LucraTitan).
- **4 PRs merged by KevinGastelum** (squash merges after review).
- All of the above is **visible in the GitHub repo** — distinct authors in the
  commit history and the contributors view, with Kevin's merges tying them
  together.
