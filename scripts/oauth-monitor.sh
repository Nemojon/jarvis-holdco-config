#!/usr/bin/env bash
# oauth-monitor.sh — Track OAuth vs API key usage across the fleet
# Shows which auth profile each agent is actually using and fallback rates
# Run: bash ~/.openclaw/scripts/oauth-monitor.sh
# Run with --alert to enable Telegram alerts when fallback rate is high

set -uo pipefail

AGENTS_DIR="/Users/apex/.openclaw/agents"
LOG="/Users/apex/.openclaw/logs/oauth-monitor.log"
ALERT_MODE="${1:-}"
TELEGRAM_BOT_TOKEN="8710384496:AAG1cWbSz0QXMp20WYwGh_8c5umtS_s8QMs"
TELEGRAM_CHAT_ID="970413391"
FALLBACK_THRESHOLD=50  # alert if >50% agents fall back to API key
mkdir -p "$(dirname "$LOG")"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=$1" -d "parse_mode=Markdown" > /dev/null 2>&1 || true
}

echo "=== OAuth Monitor — $(date '+%Y-%m-%d %H:%M %Z') ==="
echo ""

OAUTH_COUNT=0
APIKEY_COUNT=0
OAUTH_ERRORS=0
APIKEY_ERRORS=0
TOTAL=0

printf "%-15s %-12s %-20s %-8s %-20s %-8s\n" "AGENT" "ACTIVE" "OAUTH LAST USED" "ERRORS" "APIKEY LAST USED" "ERRORS"
printf "%-15s %-12s %-20s %-8s %-20s %-8s\n" "-----" "------" "---------------" "------" "---------------" "------"

for auth_file in "$AGENTS_DIR"/*/agent/auth-profiles.json; do
    [ -f "$auth_file" ] || continue
    agent=$(echo "$auth_file" | sed 's|.*/agents/||; s|/agent/.*||')
    TOTAL=$((TOTAL + 1))

    result=$(python3 -c "
import json, datetime
with open('$auth_file') as f:
    d = json.load(f)
stats = d.get('usageStats', {})
oauth_last = 0
oauth_err = 0
apikey_last = 0
apikey_err = 0
for profile, s in stats.items():
    if 'codex' in profile:
        oauth_last = max(oauth_last, s.get('lastUsed', 0))
        oauth_err += s.get('errorCount', 0)
    elif 'openai' in profile:
        apikey_last = max(apikey_last, s.get('lastUsed', 0))
        apikey_err += s.get('errorCount', 0)

def fmt(ms):
    if ms == 0: return 'never'
    return datetime.datetime.fromtimestamp(ms/1000).strftime('%m-%d %H:%M')

active = 'OAUTH' if oauth_last > apikey_last else 'APIKEY' if apikey_last > 0 else 'NONE'
print(f'{active}|{fmt(oauth_last)}|{oauth_err}|{fmt(apikey_last)}|{apikey_err}')
" 2>/dev/null)

    IFS='|' read -r active oauth_ts oauth_e apikey_ts apikey_e <<< "$result"

    if [ "$active" = "OAUTH" ]; then
        OAUTH_COUNT=$((OAUTH_COUNT + 1))
        OAUTH_ERRORS=$((OAUTH_ERRORS + oauth_e))
    elif [ "$active" = "APIKEY" ]; then
        APIKEY_COUNT=$((APIKEY_COUNT + 1))
        APIKEY_ERRORS=$((APIKEY_ERRORS + apikey_e))
    fi

    printf "%-15s %-12s %-20s %-8s %-20s %-8s\n" "$agent" "$active" "$oauth_ts" "$oauth_e" "$apikey_ts" "$apikey_e"
done

echo ""
echo "=== SUMMARY ==="
echo "Agents on OAuth:  $OAUTH_COUNT / $TOTAL"
echo "Agents on APIkey: $APIKEY_COUNT / $TOTAL (fallback)"
echo "OAuth errors:     $OAUTH_ERRORS"
echo "API key errors:   $APIKEY_ERRORS"

# Check OAuth token health
OAUTH_EXPIRES=$(python3 -c "
import json
with open('$AGENTS_DIR/orion/agent/auth-profiles.json') as f:
    d = json.load(f)
print(d['profiles']['openai-codex:jonathan.lyt89@gmail.com']['expires'])
" 2>/dev/null || echo "0")

if [ "$OAUTH_EXPIRES" != "0" ]; then
    NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))")
    REMAINING_H=$(python3 -c "print(f'{($OAUTH_EXPIRES - $NOW_MS) / 3600000:.1f}')")
    echo "OAuth token:      ${REMAINING_H}h remaining"
fi

# Calculate fallback percentage
if [ "$TOTAL" -gt 0 ]; then
    # Only count agents that have been active (not NONE)
    ACTIVE=$((OAUTH_COUNT + APIKEY_COUNT))
    if [ "$ACTIVE" -gt 0 ]; then
        FALLBACK_PCT=$(( APIKEY_COUNT * 100 / ACTIVE ))
    else
        FALLBACK_PCT=0
    fi
else
    FALLBACK_PCT=0
fi

echo "Fallback rate:    ${FALLBACK_PCT}% (threshold: ${FALLBACK_THRESHOLD}%)"

# Log snapshot
echo "[$(ts)] oauth=$OAUTH_COUNT apikey=$APIKEY_COUNT fallback=${FALLBACK_PCT}% oauth_err=$OAUTH_ERRORS apikey_err=$APIKEY_ERRORS" >> "$LOG"

if [ "$FALLBACK_PCT" -gt "$FALLBACK_THRESHOLD" ] && [ "$ALERT_MODE" = "--alert" ]; then
    echo ""
    echo "ALERT: Fallback rate ${FALLBACK_PCT}% exceeds ${FALLBACK_THRESHOLD}% threshold!"

    # Deduplicate: only alert once per 6 hours
    LAST_ALERT_FILE="/tmp/openclaw/oauth-monitor-last-alert"
    NOW_S=$(date +%s)
    SHOULD_ALERT=1
    if [ -f "$LAST_ALERT_FILE" ]; then
        LAST_ALERT_S=$(cat "$LAST_ALERT_FILE" 2>/dev/null || echo "0")
        ELAPSED=$(( NOW_S - LAST_ALERT_S ))
        if [ "$ELAPSED" -lt 21600 ]; then  # 6 hours
            SHOULD_ALERT=0
            echo "(Suppressed — last alert was $(( ELAPSED / 3600 ))h ago, next alert in $(( (21600 - ELAPSED) / 3600 ))h)"
        fi
    fi

    if [ "$SHOULD_ALERT" -eq 1 ]; then
        tg_send "⚡ *OAUTH MONITOR* — Fleet fallback rate: *${FALLBACK_PCT}%*

${OAUTH_COUNT}/${ACTIVE} agents on OAuth
${APIKEY_COUNT}/${ACTIVE} agents falling back to API key
OAuth errors: ${OAUTH_ERRORS}

ChatGPT Plus rate limits likely being hit. Consider upgrading to *ChatGPT Pro* (\$200/mo) if this persists.

Run \`bash ~/.openclaw/scripts/oauth-monitor.sh\` for full report."
        echo "$NOW_S" > "$LAST_ALERT_FILE"
        echo "Telegram alert sent to Jon."
    fi
elif [ "$FALLBACK_PCT" -gt "$FALLBACK_THRESHOLD" ]; then
    echo ""
    echo "WARNING: Majority of fleet falling back to API key!"
    echo "Run with --alert flag to enable Telegram notifications."
fi
