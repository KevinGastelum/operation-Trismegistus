# Warren Runbook

## Purpose

Warren is this project's sandboxed agent **control plane**. It dispatches
short-lived coding runs against the GitHub repo, streams events, lets you
steer/cancel mid-run, and returns work as a **branch or PR** for human review.

## Environment

- Shell: bash. On Windows use **MSYS2 / Git Bash**; on Linux/macOS use your normal shell.
  Run helpers as `bash scripts/wr-...`.
- `WARREN_BASE_URL` — Warren HTTP API base. Default `http://localhost:8080`.
- `WARREN_API_TOKEN` — required for authenticated endpoints. **Never** print,
  commit, echo, or paste it.

**You normally do NOT export the token by hand.** Every `scripts/wr-*.sh` sources
`scripts/wr-env.sh`, which auto-loads `WARREN_API_TOKEN` from your Warren server
checkout's `.env` if it isn't already set — so `bash scripts/wr-projects.sh` works
in a fresh shell. Resolution order: existing env -> `$WARREN_ENV_FILE` -> the
candidate paths listed in `wr-env.sh`. Edit those candidate paths to match where
your Warren `.env` lives. If a script prints `WARREN_API_TOKEN is required`, set
`WARREN_ENV_FILE=/abs/path/to/warren/.env` and re-run (never echo it). Manual
override still works — an already-set `WARREN_API_TOKEN` wins:

```bash
export WARREN_BASE_URL="http://localhost:8080"       # optional; this is the default
export WARREN_ENV_FILE="/abs/path/to/warren/.env"    # only if auto-load can't find it
export WARREN_API_TOKEN="...from the Warren UI..."   # only to override; never echo this
```

> If the `warren`/`wr` CLI is not on PATH (Warren running only as the Docker
> container + UI), use the HTTP API via the scripts below or the Warren UI.

> API endpoint paths/payloads follow the Warren integration spec. If your
> installed Warren version differs, adjust the scripts in `scripts/` and re-test.

## Commands

| Action | Command |
| --- | --- |
| Health (liveness + readiness) | `bash scripts/wr-health.sh` |
| List projects | `bash scripts/wr-projects.sh` |
| List agents / runtimes | `bash scripts/wr-agents.sh` |
| Dispatch a run | `bash scripts/wr-run.sh claude-code <project-id> "<prompt>"` |
| Stream events | `bash scripts/wr-events.sh <run-id>` |
| Steer a run | `bash scripts/wr-steer.sh <run-id> "<message>"` |
| Cancel a run | `bash scripts/wr-cancel.sh <run-id>` |
| Guided dispatch | `bash scripts/wr-dispatch-current-repo.sh [project-id] "<prompt>"` |

## Register this project

CLI (if installed):

```bash
warren add-project {{REPO_URL}} --default-branch {{DEFAULT_BRANCH}}
```

Otherwise register through the Warren UI, then confirm with
`bash scripts/wr-projects.sh`.

## Warren server: Claude OAuth credential mount (required once)

Warren's `claude-code` runtime authenticates inside each sandbox via your Claude
**subscription** — but only if the host's credentials *file* is mounted into the
container. burrow forwards Claude OAuth by reading `~/.claude/.credentials.json`,
**not** env vars. Without the mount the in-container `~/.claude` is empty and
every dispatched run 401s with `apiKeySource:"none"` and 0 tokens ("dead by
construction"). Setting `CLAUDE_CODE_OAUTH_TOKEN` in the container env does
**not** work.

Add this under the `warren` service `volumes:` in the Warren **server's**
`docker-compose.yml` (this is install-level config, not stamped per project):

```yaml
    volumes:
      # Linux/macOS host:
      - ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro
      # Windows host (use your own user path):
      # - C:/Users/<YOU>/.claude/.credentials.json:/root/.claude/.credentials.json:ro
```

Then recreate (env/compose changes need recreate, not just restart):

```bash
docker compose up -d --force-recreate
```

The file is read-only; your logged-in Claude Code keeps it refreshed on the host.
Copy-pasteable snippet: `~/.os-kay/warren-scaffold/warren-server-setup/`.

## When to use Warren / when not

Use Warren for isolated branch-return work, larger or risky tasks, scheduled
automation, previews, and anything that should not mutate your local tree.
Do not use it for tiny edits, secret handling, or tight human back-and-forth.

## Safety

- Never print, echo, or commit `WARREN_API_TOKEN`; never paste `.env` contents.
- Never auto-merge a Warren branch — review first.
- Never enable cron triggers without explicit human approval.
- A local guard (`.claude/hooks/warren-guard.js`) blocks the most obvious
  token/`.env` leaks and Warren project deletes. Best-effort, not a guarantee.

## Troubleshooting

```bash
bash scripts/wr-health.sh
docker compose ps                 # wherever Warren's compose file lives
docker compose logs --tail=200
warren doctor                     # if the CLI is installed
```

- 401/403 → `WARREN_API_TOKEN` unset or stale.
- Connection refused → Warren container down, or wrong `WARREN_BASE_URL`.
- `jq` is required by the dispatch/steer scripts (they build JSON payloads).
