#!/usr/bin/env bash
# ============================================================
# Agent Commit Helper (Linux/Bash version)
# Commits code as a K-bot agent with proper GitHub attribution
#
# Usage:
#   ./agent-commit.sh T1 "feat: implement neural sync"
#   ./agent-commit.sh T2 "fix: resolve memory leak" --co-author
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# === Configuration ===
COMMITTER_NAME="KevinGastelum"
COMMITTER_EMAIL="kev.gas777@gmail.com"

declare -A AGENT_NAMES=(
    ["T1"]="K-bot-T1"
    ["T2"]="K-bot-T2"
    ["T3"]="K-bot-T3"
)

declare -A AGENT_EMAILS=(
    ["T1"]="k-bot-t1@k-incorporate.local"
    ["T2"]="k-bot-t2@k-incorporate.local"
    ["T3"]="k-bot-t3@k-incorporate.local"
)

# === Argument Parsing ===
if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <T1|T2|T3> \"commit message\" [--co-author]${NC}"
    exit 1
fi

AGENT="$1"
MESSAGE="$2"
CO_AUTHOR="${3:-}"

if [[ ! "${AGENT_NAMES[$AGENT]+exists}" ]]; then
    echo -e "${RED}Error: Invalid agent. Use T1, T2, or T3${NC}"
    exit 1
fi

AGENT_NAME="${AGENT_NAMES[$AGENT]}"
AGENT_EMAIL="${AGENT_EMAILS[$AGENT]}"

if [ "$CO_AUTHOR" = "--co-author" ]; then
    # KevinGastelum is author, agent is co-author
    TRAILER="Co-authored-by: ${AGENT_NAME} <${AGENT_EMAIL}>"
    git commit -m "$MESSAGE" -m "$TRAILER"
    echo -e "\n${GREEN}✅ Committed as ${COMMITTER_NAME} with co-author: ${AGENT_NAME}${NC}"
else
    # Agent is author, KevinGastelum is committer
    GIT_AUTHOR_NAME="$AGENT_NAME" \
    GIT_AUTHOR_EMAIL="$AGENT_EMAIL" \
    GIT_COMMITTER_NAME="$COMMITTER_NAME" \
    GIT_COMMITTER_EMAIL="$COMMITTER_EMAIL" \
    git commit -m "$MESSAGE"
    echo -e "\n${GREEN}✅ Committed as author: ${AGENT_NAME}, committer: ${COMMITTER_NAME}${NC}"
fi

echo -e "${CYAN}📋 Last commit:${NC}"
git log -1 --format="   Author:    %an <%ae>%n   Committer: %cn <%ce>%n   Message:   %s"
