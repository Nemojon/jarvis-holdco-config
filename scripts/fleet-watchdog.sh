#!/usr/bin/env bash
# =============================================================================
# fleet-watchdog.sh — Monitors ALL agents + gateway + channels
#
# Runs every 15 minutes via launchd. Checks:
# 1. Gateway health
# 2. Telegram bot connectivity
# 3. WhatsApp channel
# 4. All agent session health (stuck sessions, timeouts)
# 5. Cron job failures
# 6. Auto-recovers where possible
#
# Created: 2026-04-08 by Cortex
# =============================================================================

set -uo pipefail

LOG="/tmp/openclaw/fleet-watchdog.log"
GATEWAY_ERR="/Users/apex/.openclaw/logs/gateway.err.log"
GATEWAY_LOG="/Users/apex/.openclaw/logs/gateway.log"
GATEWAY_HEALTH="http://localhost:18789/health"
JON_CHAT_ID="970413391"
BOT_TOKEN="${TELEGRAM_DEFAULT_BOT_TOKEN:-}"
LOOKBACK=900  # 15 minutes in seconds

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
        curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d "chat_id=${JON_CHAT_ID}" \
            -d "text=${msg}" > /dev/null 2>&1
    fi
}

ISSUES=""
FIXES=""
add_issue() { ISSUES="${ISSUES}• $1\n"; }
add_fix() { FIXES="${FIXES}• $1\n"; }

log "=== Fleet Watchdog Check ==="

# ── CHECK 1: Gateway Health ──
HEALTH=$(curl -s --max-time 5 "$GATEWAY_HEALTH" 2>/dev/null)
if ! echo "$HEALTH" | grep -q '"ok":true'; then
    log "CRITICAL: Gateway DOWN"
    launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
    sleep 10
    HEALTH=$(curl -s --max-time 5 "$GATEWAY_HEALTH" 2>/dev/null)
    if echo "$HEALTH" | grep -q '"ok":true'; then
        add_fix "Gateway was down — restarted successfully"
        log "Gateway restarted"
    else
        add_issue "Gateway DOWN and restart FAILED"
        log "Gateway restart FAILED"
        send_telegram "[FLEET WATCHDOG] CRITICAL: Gateway is down and restart failed. Manual intervention needed on Cortex."
        exit 1
    fi
else
    log "Gateway: OK"
fi

# ── CHECK 2: LaunchD Services ──
EXPECTED_SERVICES="ai.openclaw.gateway ai.openclaw.jarvis-watchdog"
for svc in $EXPECTED_SERVICES; do
    STATUS=$(launchctl list 2>/dev/null | grep "$svc" | awk '{print $1}')
    if [ -z "$STATUS" ]; then
        add_issue "$svc not loaded"
        log "$svc: NOT LOADED"
    elif [ "$STATUS" = "-" ]; then
        log "$svc: loaded (idle)"
    else
        log "$svc: running (pid=$STATUS)"
    fi
done

# ── CHECK 3: Telegram Bot Connectivity ──
if [ -n "$BOT_TOKEN" ]; then
    TG_CHECK=$(curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/getMe" 2>/dev/null)
    if echo "$TG_CHECK" | grep -q '"ok":true'; then
        log "Telegram bot: OK"
    else
        add_issue "Telegram bot token invalid or unreachable"
        log "Telegram bot: FAILED"
    fi
fi

# ── CHECK 4: Agent LLM Timeouts (last 15 min) ──
NOW_EPOCH=$(date "+%s")
AGENTS="orion apex atlas hunter recon signal ledger cto aurora counsel pastor-zion"

for agent in $AGENTS; do
    TIMEOUT_COUNT=$(grep "session:agent:${agent}" "$GATEWAY_ERR" 2>/dev/null | \
        grep "timed out\|FailoverError" | \
        while read -r line; do
            timestamp=$(echo "$line" | grep -oE '2026-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
            if [ -n "$timestamp" ]; then
                line_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null)
                diff=$((NOW_EPOCH - line_epoch))
                if [ "$diff" -lt "$LOOKBACK" ]; then
                    echo "1"
                fi
            fi
        done | wc -l | tr -d ' ')

    if [ "$TIMEOUT_COUNT" -ge 3 ] 2>/dev/null; then
        add_issue "Agent $agent: $TIMEOUT_COUNT LLM timeouts in last 15min"
        log "Agent $agent: $TIMEOUT_COUNT timeouts — clearing sessions"

        # Auto-fix: wipe that agent's sessions
        rm -rf "/Users/apex/.openclaw/agents/${agent}/sessions/archive/" 2>/dev/null
        rm -f "/Users/apex/.openclaw/agents/${agent}/sessions/"*.jsonl 2>/dev/null
        rm -f "/Users/apex/.openclaw/agents/${agent}/sessions/"*.lock 2>/dev/null
        add_fix "Wiped ${agent} sessions (${TIMEOUT_COUNT} timeouts)"
    fi
done

# ── CHECK 5: Session Mismatch Errors ──
MISMATCH_COUNT=$(grep "does not match session key" "$GATEWAY_ERR" 2>/dev/null | \
    while read -r line; do
        timestamp=$(echo "$line" | grep -oE '2026-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
        if [ -n "$timestamp" ]; then
            line_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null)
            diff=$((NOW_EPOCH - line_epoch))
            if [ "$diff" -lt "$LOOKBACK" ]; then
                echo "1"
            fi
        fi
    done | wc -l | tr -d ' ')

if [ "$MISMATCH_COUNT" -ge 3 ] 2>/dev/null; then
    add_issue "$MISMATCH_COUNT session mismatch errors in last 15min"
    log "Session mismatches: $MISMATCH_COUNT — clearing all locks"
    find /Users/apex/.openclaw/agents/*/sessions/ -name "*.lock" -delete 2>/dev/null
    add_fix "Cleared all session locks"
fi

# ── CHECK 6: Config Validation ──
CONFIG_CHECK=$(grep "Config invalid" "$GATEWAY_ERR" 2>/dev/null | \
    while read -r line; do
        timestamp=$(echo "$line" | grep -oE '2026-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
        if [ -n "$timestamp" ]; then
            line_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null)
            diff=$((NOW_EPOCH - line_epoch))
            if [ "$diff" -lt "$LOOKBACK" ]; then
                echo "1"
            fi
        fi
    done | wc -l | tr -d ' ')

if [ "$CONFIG_CHECK" -ge 1 ] 2>/dev/null; then
    add_issue "Config validation errors detected — gateway may have crashed"
    log "Config errors found"
fi

# ── CHECK 7: WhatsApp Channel ──
WA_TIMEOUT=$(grep "whatsapp.*ETIMEDOUT\|whatsapp.*error\|whatsapp.*exited" "$GATEWAY_ERR" 2>/dev/null | \
    while read -r line; do
        timestamp=$(echo "$line" | grep -oE '2026-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
        if [ -n "$timestamp" ]; then
            line_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null)
            diff=$((NOW_EPOCH - line_epoch))
            if [ "$diff" -lt "$LOOKBACK" ]; then
                echo "1"
            fi
        fi
    done | wc -l | tr -d ' ')

if [ "$WA_TIMEOUT" -ge 1 ] 2>/dev/null; then
    add_issue "WhatsApp channel errors detected"
    log "WhatsApp: errors found"
fi

# ── DECISION: Restart gateway if fixes were applied ──
if [ -n "$FIXES" ]; then
    log "Restarting gateway after fixes"
    launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
    sleep 10
    HEALTH=$(curl -s --max-time 5 "$GATEWAY_HEALTH" 2>/dev/null)
    if echo "$HEALTH" | grep -q '"ok":true'; then
        add_fix "Gateway restarted after cleanup"
    else
        add_issue "Gateway failed to restart after cleanup"
    fi
fi

# ── REPORT ──
if [ -n "$ISSUES" ] || [ -n "$FIXES" ]; then
    REPORT="[FLEET WATCHDOG]"
    if [ -n "$ISSUES" ]; then
        REPORT="${REPORT}\n\nIssues:\n${ISSUES}"
    fi
    if [ -n "$FIXES" ]; then
        REPORT="${REPORT}\nAuto-fixed:\n${FIXES}"
    fi
    log "Issues found — sending alert"
    send_telegram "$(echo -e "$REPORT")"
else
    log "All clear — no issues"
fi

# Rotate log
if [ -f "$LOG" ]; then
    tail -1000 "$LOG" > "${LOG}.tmp" 2>/dev/null
    mv "${LOG}.tmp" "$LOG" 2>/dev/null
fi
