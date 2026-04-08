#!/usr/bin/env bash
# =============================================================================
# jarvis-watchdog.sh — Monitors Jarvis Telegram responsiveness
#
# Runs every 30 minutes via launchd. If Jarvis's Telegram lane has been
# timing out, automatically wipes sessions, clears lancedb, restarts gateway,
# and sends a recovery notification to Jon.
#
# Created: 2026-04-08 by Cortex
# =============================================================================

set -uo pipefail

LOG="/tmp/openclaw/jarvis-watchdog.log"
GATEWAY_LOG="/Users/apex/.openclaw/logs/gateway.err.log"
GATEWAY_HEALTH="http://localhost:18789/health"
JON_CHAT_ID="970413391"
BOT_TOKEN="${TELEGRAM_DEFAULT_BOT_TOKEN:-}"

mkdir -p /tmp/openclaw

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# Load env if bot token not set
if [ -z "$BOT_TOKEN" ]; then
    for envfile in /Users/apex/.openclaw/.env /Users/apex/.openclaw/.env.local; do
        if [ -f "$envfile" ]; then
            export $(grep TELEGRAM_DEFAULT_BOT_TOKEN "$envfile" 2>/dev/null | xargs) 2>/dev/null
        fi
    done
    BOT_TOKEN="${TELEGRAM_DEFAULT_BOT_TOKEN:-}"
fi

send_telegram() {
    local msg="$1"
    if [ -n "$BOT_TOKEN" ]; then
        curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d "chat_id=${JON_CHAT_ID}" \
            -d "text=${msg}" > /dev/null 2>&1
    fi
}

log "=== Jarvis Watchdog Check ==="

# Check 1: Is gateway alive?
HEALTH=$(curl -s --max-time 5 "$GATEWAY_HEALTH" 2>/dev/null)
if ! echo "$HEALTH" | grep -q '"ok":true'; then
    log "CRITICAL: Gateway is DOWN. Attempting restart."
    launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
    sleep 10
    HEALTH=$(curl -s --max-time 5 "$GATEWAY_HEALTH" 2>/dev/null)
    if echo "$HEALTH" | grep -q '"ok":true'; then
        log "Gateway restarted successfully"
    else
        log "Gateway restart FAILED"
        send_telegram "[WATCHDOG] Gateway is down and restart failed. Manual intervention needed."
        exit 1
    fi
fi

# Check 2: Has Jarvis's Telegram lane been timing out in the last 30 minutes?
RECENT_TIMEOUTS=$(grep "session:agent:orion:telegram" "$GATEWAY_LOG" 2>/dev/null | \
    grep "FailoverError.*timed out\|LLM request timed out" | \
    awk -F'T' '{print $1"T"$2}' | \
    while read -r line; do
        timestamp=$(echo "$line" | grep -oE '2026-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
        if [ -n "$timestamp" ]; then
            line_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null)
            now_epoch=$(date "+%s")
            diff=$((now_epoch - line_epoch))
            if [ "$diff" -lt 1800 ]; then
                echo "$timestamp"
            fi
        fi
    done | wc -l | tr -d ' ')

log "Recent Telegram timeouts (last 30min): $RECENT_TIMEOUTS"

# Check 3: Session mismatch errors (agent X does not match session key)
RECENT_MISMATCHES=$(grep "does not match session key" "$GATEWAY_LOG" 2>/dev/null | \
    awk -F'T' '{print $1"T"$2}' | \
    while read -r line; do
        timestamp=$(echo "$line" | grep -oE '2026-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
        if [ -n "$timestamp" ]; then
            line_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null)
            now_epoch=$(date "+%s")
            diff=$((now_epoch - line_epoch))
            if [ "$diff" -lt 1800 ]; then
                echo "$timestamp"
            fi
        fi
    done | wc -l | tr -d ' ')

log "Recent session mismatches (last 30min): $RECENT_MISMATCHES"

# Decision: if 3+ timeouts or 3+ mismatches in last 30 min, auto-recover
NEEDS_RECOVERY=false
REASON=""

if [ "$RECENT_TIMEOUTS" -ge 3 ] 2>/dev/null; then
    NEEDS_RECOVERY=true
    REASON="$RECENT_TIMEOUTS Telegram LLM timeouts in last 30min"
    log "TRIGGER: $REASON"
fi

if [ "$RECENT_MISMATCHES" -ge 3 ] 2>/dev/null; then
    NEEDS_RECOVERY=true
    REASON="${REASON:+$REASON + }$RECENT_MISMATCHES session mismatch errors in last 30min"
    log "TRIGGER: $REASON"
fi

if [ "$NEEDS_RECOVERY" = true ]; then
    log "AUTO-RECOVERY: Wiping Jarvis sessions + restarting gateway"

    # Wipe Jarvis sessions
    rm -rf /Users/apex/.openclaw/agents/orion/sessions/archive/ 2>/dev/null
    rm -f /Users/apex/.openclaw/agents/orion/sessions/*.jsonl 2>/dev/null
    rm -f /Users/apex/.openclaw/agents/orion/sessions/*.lock 2>/dev/null

    # Clear all session locks
    find /Users/apex/.openclaw/agents/*/sessions/ -name "*.lock" -delete 2>/dev/null

    # Clear lancedb if it's injecting bad memories
    rm -rf /Users/apex/.openclaw/memory/lancedb/memories.lance 2>/dev/null

    # Restart gateway
    launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
    sleep 10

    # Verify gateway is back
    HEALTH=$(curl -s --max-time 5 "$GATEWAY_HEALTH" 2>/dev/null)
    if echo "$HEALTH" | grep -q '"ok":true'; then
        log "AUTO-RECOVERY SUCCESS: Gateway restarted, sessions cleared"
        send_telegram "[WATCHDOG] Jarvis auto-recovered. Reason: ${REASON}. Sessions wiped, gateway restarted. Jarvis should be responsive now."
    else
        log "AUTO-RECOVERY PARTIAL: Sessions cleared but gateway may need manual restart"
        send_telegram "[WATCHDOG] Jarvis sessions cleared but gateway may be down. Check Cortex."
    fi
else
    log "OK: No recovery needed. Jarvis Telegram lane healthy."
fi

# Rotate watchdog log (keep last 500 lines)
if [ -f "$LOG" ]; then
    tail -500 "$LOG" > "${LOG}.tmp" 2>/dev/null
    mv "${LOG}.tmp" "$LOG" 2>/dev/null
fi
