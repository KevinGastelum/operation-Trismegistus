# Team commit-attribution -- route commits by changed path -> role.
commit MSG:
    bun .team/team-commit.ts "{{MSG}}"

commit-push MSG:
    bun .team/team-commit.ts "{{MSG}}" --push

commit-solo MSG:
    bun .team/team-commit.ts "{{MSG}}" --solo

team-status:
    bun .team/team-commit.ts --dry-run

# Show live project state: Warren health, active seeds, and STATUS.md summary.
status:
    @echo "=== Warren health ==="; bash scripts/wr-health.sh 2>&1 || true
    @echo ""
    @echo "=== Seeds — in flight ==="; sd list --status=in_progress --format=compact 2>&1 || true
    @echo ""
    @echo "=== Seeds — ready (unblocked) ==="; sd ready --format=compact 2>&1 || true
    @echo ""
    @echo "=== STATUS.md ==="; cat STATUS.md 2>/dev/null || echo "(STATUS.md not found)"
