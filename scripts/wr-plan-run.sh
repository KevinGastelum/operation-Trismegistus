#!/usr/bin/env bash
# Launch a Warren plan-run for a committed Seeds plan.
# Usage: wr-plan-run.sh <project-id> <plan-id> [agent] [merge-timeout-ms]
# Example: wr-plan-run.sh prj_203c32jc0bqz pl-a703 claude-code 0
# merge-timeout-ms: 0 = no timeout; omit to use server default (~30 min per child).
# The plan's child seeds are read server-side from the repo's committed .seeds/.
# Requires WARREN_API_TOKEN (auto-loaded via wr-env.sh) and jq. Never prints the token.
set -euo pipefail

project_id="${1:?project id required}"
plan_id="${2:?plan id required, e.g. pl-a703}"
agent="${3:-claude-code}"
merge_timeout_ms="${4:-}"

WARREN_BASE_URL="${WARREN_BASE_URL:-http://localhost:8080}"
source "$(dirname "${BASH_SOURCE[0]}")/wr-env.sh"  # auto-load WARREN_API_TOKEN
: "${WARREN_API_TOKEN:?WARREN_API_TOKEN is required}"
command -v jq >/dev/null 2>&1 || { echo "jq is required for wr-plan-run.sh" >&2; exit 1; }

if [[ -n "$merge_timeout_ms" ]]; then
  payload="$(jq -n \
    --arg project "$project_id" \
    --arg planId "$plan_id" \
    --arg agent "$agent" \
    --argjson mergeTimeoutMs "$merge_timeout_ms" \
    '{project:$project, planId:$planId, agent:$agent, mergeTimeoutMs:$mergeTimeoutMs}')"
else
  payload="$(jq -n \
    --arg project "$project_id" \
    --arg planId "$plan_id" \
    --arg agent "$agent" \
    '{project:$project, planId:$planId, agent:$agent}')"
fi

curl -fsS \
  -X POST \
  -H "Authorization: Bearer ${WARREN_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${WARREN_BASE_URL%/}/plan-runs" \
  -d "$payload" | jq . 2>/dev/null || cat
