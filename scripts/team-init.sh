#!/usr/bin/env bash
# Install the team-commit convention into a target repo.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"

mkdir -p "$TARGET/.team"
cp "$SRC/.team/roster.json"    "$TARGET/.team/roster.json"
cp "$SRC/.team/routing.ts"     "$TARGET/.team/routing.ts"
cp "$SRC/.team/team-commit.ts" "$TARGET/.team/team-commit.ts"

JF="$TARGET/justfile"
if [ ! -f "$JF" ] || ! grep -q "team-commit.ts" "$JF"; then
  cat >> "$JF" <<'EOF'

# Team commit-attribution -- route commits by changed path -> role.
commit MSG:
    bun .team/team-commit.ts "{{MSG}}"

commit-push MSG:
    bun .team/team-commit.ts "{{MSG}}" --push

commit-solo MSG:
    bun .team/team-commit.ts "{{MSG}}" --solo

team-status:
    bun .team/team-commit.ts --dry-run
EOF
fi

# Warn-only verification of roster accounts against GitHub.
if command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  while read -r login id; do
    real="$(gh api "users/$login" --jq .id 2>/dev/null || echo "")"
    if [ -n "$real" ] && [ "$real" != "$id" ]; then
      echo "warn: roster $login id=$id but GitHub reports $real"
    fi
  done < <(jq -r '.roles[] | "\(.login) \(.id)"' "$TARGET/.team/roster.json")
fi

echo "team-init: installed into $TARGET"
echo "  preview:  just team-status   (or: bun .team/team-commit.ts --dry-run)"
echo "  commit:   just commit \"message\""
