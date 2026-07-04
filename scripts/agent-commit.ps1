<#
.SYNOPSIS
    Agent Commit Helper — Commits code as a K-bot agent with proper GitHub attribution.

.DESCRIPTION
    This script sets the Git author to the specified agent (K-bot-T1, T2, or T3)
    while keeping the committer as KevinGastelum. This means:
    - GitHub shows the commit under KevinGastelum's account
    - The commit metadata shows which agent authored it
    - `git log --format="%an"` will show the agent name

.PARAMETER Agent
    The agent identifier: T1, T2, or T3

.PARAMETER Message
    The commit message

.PARAMETER CoAuthor
    If set, uses Co-authored-by trailer instead of author override

.EXAMPLE
    .\agent-commit.ps1 -Agent T1 -Message "feat: implement neural sync"
    .\agent-commit.ps1 -Agent T2 -Message "fix: resolve memory leak" -CoAuthor
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("T1", "T2", "T3")]
    [string]$Agent,

    [Parameter(Mandatory=$true)]
    [string]$Message,

    [switch]$CoAuthor
)

# === Configuration ===
$COMMITTER_NAME = "KevinGastelum"
$COMMITTER_EMAIL = "kev.gas777@gmail.com"

$agents = @{
    "T1" = @{ Name = "K-bot-T1"; Email = "k-bot-t1@k-incorporate.local" }
    "T2" = @{ Name = "K-bot-T2"; Email = "k-bot-t2@k-incorporate.local" }
    "T3" = @{ Name = "K-bot-T3"; Email = "k-bot-t3@k-incorporate.local" }
}

$agentInfo = $agents[$Agent]

if ($CoAuthor) {
    # Method: KevinGastelum is author, agent is co-author
    $trailer = "Co-authored-by: $($agentInfo.Name) <$($agentInfo.Email)>"
    git commit -m $Message -m $trailer
    Write-Host "`n✅ Committed as $COMMITTER_NAME with co-author: $($agentInfo.Name)" -ForegroundColor Green
} else {
    # Method: Agent is author, KevinGastelum is committer
    $env:GIT_AUTHOR_NAME = $agentInfo.Name
    $env:GIT_AUTHOR_EMAIL = $agentInfo.Email
    $env:GIT_COMMITTER_NAME = $COMMITTER_NAME
    $env:GIT_COMMITTER_EMAIL = $COMMITTER_EMAIL

    git commit -m $Message

    # Clean up env vars
    Remove-Item Env:\GIT_AUTHOR_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_AUTHOR_EMAIL -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_COMMITTER_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_COMMITTER_EMAIL -ErrorAction SilentlyContinue

    Write-Host "`n✅ Committed as author: $($agentInfo.Name), committer: $COMMITTER_NAME" -ForegroundColor Green
}

Write-Host "📋 Last commit:" -ForegroundColor Cyan
git log -1 --format="   Author:    %an <%ae>%n   Committer: %cn <%ce>%n   Message:   %s"
