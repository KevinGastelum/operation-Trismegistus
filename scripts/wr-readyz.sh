#!/usr/bin/env bash
# Warren readiness detail: shows which /readyz checks are failing.
# Unlike wr-health.sh, does NOT use curl -f, so a 503 still yields the check list.
# Never prints WARREN_API_TOKEN.
set -euo pipefail

WARREN_BASE_URL="${WARREN_BASE_URL:-http://localhost:8080}"
source "$(dirname "${BASH_SOURCE[0]}")/wr-env.sh"  # auto-load WARREN_API_TOKEN

if [ -z "${WARREN_API_TOKEN:-}" ]; then
  echo "WARREN_API_TOKEN is not set; cannot query /readyz." >&2
  exit 1
fi

curl -sS -H "Authorization: Bearer ${WARREN_API_TOKEN}" "${WARREN_BASE_URL}/readyz" \
  | jq '{ok, failing: [.checks[] | select(.ok==false) | {name, detail}], all: [.checks[] | {name, ok}]}'
