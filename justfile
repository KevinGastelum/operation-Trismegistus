# Team commit-attribution -- route commits by changed path -> role.
commit MSG:
    bun .team/team-commit.ts "{{MSG}}"

commit-push MSG:
    bun .team/team-commit.ts "{{MSG}}" --push

commit-solo MSG:
    bun .team/team-commit.ts "{{MSG}}" --solo

team-status:
    bun .team/team-commit.ts --dry-run
