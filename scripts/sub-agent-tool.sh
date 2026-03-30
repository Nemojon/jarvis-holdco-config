#!/bin/bash
# sub-agent-tool.sh — Delegation wrapper for OpenClaw agents
# Usage: sub-agent-tool.sh <agent> <task> [context]
# Logs to delegation_log table and ~/.openclaw/logs/delegation.log
# Created: 2026-03-27

set -euo pipefail

VALID_AGENTS="apex atlas aurora cto hunter ledger main orion pastor-zion recon signal"
DB="$HOME/.openclaw/memory/agent_lab.sqlite"
LOG="$HOME/.openclaw/logs/delegation.log"
CALLER="${OPENCLAW_CALLER_AGENT:-cli}"

agent="${1:-}"
task="${2:-}"
context="${3:-}"

if [ -z "$agent" ] || [ -z "$task" ]; then
  echo "Usage: sub-agent-tool.sh <agent> <task> [context]"
  echo "Valid agents: $VALID_AGENTS"
  exit 1
fi

# Validate agent
if ! echo "$VALID_AGENTS" | grep -qw "$agent"; then
  echo "Error: unknown agent '$agent'. Valid: $VALID_AGENTS"
  exit 1
fi

# Execute
start_ms=$(python3 -c "import time; print(int(time.time()*1000))")

result=$(timeout 120 openclaw agent --agent "$agent" -m "$task" --json 2>/dev/null) || true
exit_code=$?

end_ms=$(python3 -c "import time; print(int(time.time()*1000))")
duration=$((end_ms - start_ms))

# Extract outcome and tokens from JSON response
outcome="success"
tokens="NULL"
if [ -n "$result" ]; then
  parsed=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    text = d.get('result',{}).get('payloads',[{}])[0].get('text','')[:200]
    usage = d.get('result',{}).get('usage',{})
    tokens = usage.get('input_tokens',0) + usage.get('output_tokens',0)
    print(f'{tokens}|{text}')
except:
    print('0|parse_error')
" 2>/dev/null) || parsed="0|error"
  tokens=$(echo "$parsed" | cut -d'|' -f1)
  response=$(echo "$parsed" | cut -d'|' -f2-)
else
  outcome="timeout"
  response=""
fi

if [ $exit_code -ne 0 ] && [ "$outcome" != "timeout" ]; then
  outcome="error:$exit_code"
fi

# Log to SQLite
task_esc=$(echo "$task" | sed "s/'/''/g")
ctx_esc=$(echo "$context" | sed "s/'/''/g")
outcome_esc=$(echo "$outcome" | sed "s/'/''/g")

sqlite3 "$DB" "INSERT INTO delegation_log (calling_agent, target_agent, task, context, outcome, tokens_used, duration_ms) VALUES ('$CALLER', '$agent', '$task_esc', '$ctx_esc', '$outcome_esc', $tokens, $duration);" 2>/dev/null || true

# Log to file
mkdir -p "$(dirname "$LOG")"
echo "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ) | caller=$CALLER | agent=$agent | outcome=$outcome | tokens=$tokens | duration=${duration}ms | task=\"${task:0:80}\"" >> "$LOG"

# Output response
if [ -n "$response" ]; then
  echo "$response"
fi
