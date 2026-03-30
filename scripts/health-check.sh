#!/bin/bash
# health-check.sh — Pre-flight OAuth token health check for all 11 agents
# Runs at 21:45 WITA daily. Alerts via Telegram on failures.
# Created: 2026-03-27

set -uo pipefail

AGENTS="apex atlas aurora cto hunter ledger main orion pastor-zion recon signal"
AGENTS_DIR="$HOME/.openclaw/agents"
LOG="$HOME/.openclaw/logs/health-check.log"
BOT_TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json'))['channels']['telegram']['botToken'])" 2>/dev/null)
CHAT_ID="970413391"

mkdir -p "$(dirname "$LOG")"

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "[$ts] Health check starting" >> "$LOG"

failed_agents=""
checked=0
passed=0

for agent in $AGENTS; do
  ap="$AGENTS_DIR/$agent/agent/auth-profiles.json"
  if [ ! -f "$ap" ]; then
    echo "[$ts] $agent: NO AUTH FILE" >> "$LOG"
    failed_agents="$failed_agents $agent(no-auth)"
    checked=$((checked+1))
    continue
  fi

  # Check Anthropic OAuth token expiry
  result=$(python3 -c "
import json, time
d = json.load(open('$ap'))
for k, v in d.get('profiles', {}).items():
    if v.get('provider') == 'anthropic' and v.get('type') == 'oauth':
        exp = v.get('expires', 0)
        remaining_min = (exp - time.time()*1000) / 60000
        if remaining_min < 30:
            print(f'EXPIRED({remaining_min:.0f}m)')
        else:
            print(f'OK({remaining_min:.0f}m)')
        break
else:
    print('NO_ANTHROPIC')
" 2>/dev/null)

  checked=$((checked+1))

  if echo "$result" | grep -q "^OK"; then
    passed=$((passed+1))
    echo "[$ts] $agent: $result" >> "$LOG"
  else
    echo "[$ts] $agent: FAIL — $result" >> "$LOG"
    failed_agents="$failed_agents $agent($result)"
  fi
done

echo "[$ts] Health check complete: $passed/$checked passed" >> "$LOG"

# Alert on failures
if [ -n "$failed_agents" ] && [ -n "$BOT_TOKEN" ]; then
  msg="⚠️ *Agent Health Check Failed*

$(date '+%Y-%m-%d %H:%M WITA')

Failed agents:$failed_agents

Checked: $checked | Passed: $passed

Run: \`bash ~/.openclaw/scripts/sync-oauth.sh\` to refresh tokens"

  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo "$msg" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"), \"parse_mode\": \"Markdown\"}" \
    > /dev/null 2>&1

  echo "[$ts] Alert sent to Telegram" >> "$LOG"
fi
