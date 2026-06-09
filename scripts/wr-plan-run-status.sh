#!/usr/bin/env bash
# Show a Warren plan-run's state, children, and child run PRs.
# Usage: wr-plan-run-status.sh <plan-run-id> [--raw]
# Get the plan-run id from wr-plan-run.sh's response (.planRun.id).
# Requires WARREN_API_TOKEN (auto-loaded via wr-env.sh) and jq. Never prints the token.
set -euo pipefail

plan_run_id="${1:?plan-run id required (.planRun.id from wr-plan-run.sh)}"
raw="${2:-}"

WARREN_BASE_URL="${WARREN_BASE_URL:-http://localhost:8080}"
source "$(dirname "${BASH_SOURCE[0]}")/wr-env.sh"  # auto-load WARREN_API_TOKEN
: "${WARREN_API_TOKEN:?WARREN_API_TOKEN is required}"

resp="$(curl -fsS \
  -H "Authorization: Bearer ${WARREN_API_TOKEN}" \
  "${WARREN_BASE_URL%/}/plan-runs/${plan_run_id}")"

if [ "$raw" = "--raw" ]; then
  echo "$resp" | jq .
else
  echo "$resp" | jq '{
    state: .planRun.state,
    planId: .planRun.planId,
    children: [.children[]? | {seq, seedId, state, prMergedAt, failureReason}],
    runs: [.runs[]? | {id, state, prUrl}]
  }' 2>/dev/null || echo "$resp"
fi
