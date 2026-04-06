#!/usr/bin/env bash
# model-guard.sh — Prevents model contamination across the fleet
# Checks openclaw.json, cron/jobs.json, and all sessions.json for bad models
# If contamination found: alerts Jon on Telegram
# Runs as part of System Watchdog (every 3 hours)

set -uo pipefail

BAD_MODELS=("gpt-4.1" "gpt-4.1-mini" "gpt-5.3-codex" "gpt-4o" "gpt-3.5" "claude-3" "claude-sonnet" "claude-opus" "claude-haiku")
TELEGRAM_BOT_TOKEN="8710384496:AAG1cWbSz0QXMp20WYwGh_8c5umtS_s8QMs"
TELEGRAM_CHAT_ID="970413391"
LOG="/Users/apex/.openclaw/logs/model-guard.log"

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
alert() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=$1" -d "parse_mode=Markdown" > /dev/null 2>&1 || true
}

DIRTY=0

# Check cron jobs
for bad in "${BAD_MODELS[@]}"; do
    count=$(grep -c "\"$bad\"" /Users/apex/.openclaw/cron/jobs.json 2>/dev/null || true)
    count=$(echo "$count" | tr -d '[:space:]')
    [ -z "$count" ] && count=0
    if [ "$count" -gt 0 ] 2>/dev/null; then
        log "CONTAMINATION: $count refs to $bad in cron/jobs.json"
        DIRTY=$((DIRTY + count))
    fi
done

# Check agent configs
for bad in "${BAD_MODELS[@]}"; do
    count=$(grep -c "\"openai/$bad\"" /Users/apex/.openclaw/openclaw.json 2>/dev/null || true)
    count=$(echo "$count" | tr -d '[:space:]')
    [ -z "$count" ] && count=0
    if [ "$count" -gt 0 ] 2>/dev/null; then
        log "CONTAMINATION: $count refs to $bad in openclaw.json"
        DIRTY=$((DIRTY + count))
    fi
done

# Check session stores
for sfile in /Users/apex/.openclaw/agents/*/sessions/sessions.json; do
    [ -f "$sfile" ] || continue
    for bad in "${BAD_MODELS[@]}"; do
        count=$(grep -c "\"$bad\"" "$sfile" 2>/dev/null || true)
        count=$(echo "$count" | tr -d '[:space:]')
        [ -z "$count" ] && count=0
        if [ "$count" -gt 0 ] 2>/dev/null; then
            agent=$(echo "$sfile" | sed 's|.*/agents/||; s|/sessions.*||')
            log "CONTAMINATION: $count refs to $bad in $agent sessions"
            DIRTY=$((DIRTY + count))
        fi
    done
done

if [ "$DIRTY" -gt 0 ]; then
    log "ALERT: $DIRTY total contaminated model references found!"
    alert "🚨 *MODEL GUARD ALERT* — $DIRTY bad model references detected in fleet config! Run Cortex model scan immediately."
else
    log "OK: Fleet model config clean"
fi
