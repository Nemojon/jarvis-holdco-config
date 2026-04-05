#!/usr/bin/env bash
# =============================================================================
# cortex-bridge.sh — Bridge between Openclaw agents and Cortex (Claude Code)
#
# Usage: bash cortex-bridge.sh "Your task description here"
#
# This script lets any Openclaw agent send a task to Cortex (Claude Code)
# and get the result back. Cortex has Canva MCP, Gamma MCP, and premium
# design tools that Openclaw agents don't have access to.
#
# Examples:
#   bash cortex-bridge.sh "Create 3 e-book cover designs for 'Prompt Like a CEO'"
#   bash cortex-bridge.sh "Check cortex-inbox and execute all pending requests"
#   bash cortex-bridge.sh "Generate a carousel design with these slides: ..."
# =============================================================================

set -uo pipefail

TASK="$*"
LOG="/tmp/openclaw/cortex-bridge.log"
INBOX="/Users/apex/.openclaw/vault/cortex-inbox"
MAX_TIMEOUT=300  # 5 minutes max

mkdir -p /tmp/openclaw

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

if [ -z "$TASK" ]; then
  echo "ERROR: No task provided. Usage: cortex-bridge.sh \"task description\""
  exit 1
fi

log "BRIDGE REQUEST: $TASK"

# Run Claude Code with the task
RESULT=$(timeout $MAX_TIMEOUT claude -p "$TASK" --output-format text 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  log "BRIDGE SUCCESS: $(echo "$RESULT" | head -1)"
  echo "$RESULT"
else
  log "BRIDGE FAILED: exit=$EXIT_CODE output=$(echo "$RESULT" | head -1)"
  echo "CORTEX BRIDGE ERROR: Task failed (exit code $EXIT_CODE). Output: $RESULT"
fi
