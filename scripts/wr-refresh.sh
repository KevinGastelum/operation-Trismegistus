#!/usr/bin/env bash
# Refresh Warren's server-side clone of a project (git pull + re-read .warren/ + .seeds/).
# Run after pushing changes to .warren/ or .seeds/ so the live instance picks them up.
# Project id defaults to $WARREN_PROJECT_ID, else the first arg. Never prints WARREN_API_TOKEN.
set -euo pipefail

WARREN_BASE_URL="${WARREN_BASE_URL:-http://localhost:8080}"
source "$(dirname "${BASH_SOURCE[0]}")/wr-env.sh"  # auto-load WARREN_API_TOKEN + WARREN_PROJECT_ID

PROJECT_ID="${1:-${WARREN_PROJECT_ID:-}}"
if [ -z "$PROJECT_ID" ]; then
  echo "usage: wr-refresh.sh <project-id>  (or set WARREN_PROJECT_ID)" >&2
  exit 1
fi
if [ -z "${WARREN_API_TOKEN:-}" ]; then
  echo "WARREN_API_TOKEN is not set; cannot refresh." >&2
  exit 1
fi

echo "Refreshing Warren clone for ${PROJECT_ID} ..."
curl -sS -X POST -H "Authorization: Bearer ${WARREN_API_TOKEN}" \
  "${WARREN_BASE_URL}/projects/${PROJECT_ID}/refresh" | jq . 2>/dev/null || true
