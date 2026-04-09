#!/usr/bin/env bash
# =============================================================================
# auto-heal.sh — Detect patterns in failure logs and attempt automated fixes.
# Runs every 2 hours via launchd (ai.openclaw.auto-heal.plist).
#
# Patterns handled:
#   1. Channel errors in cron delivery → fix delivery config in jobs.json
#   2. OAuth token expiry → run token-keeper.sh
#   3. Gateway unresponsive → trigger gateway-watchdog.sh
#   4. Cron jobs with 3+ consecutive errors → disable and alert
# =============================================================================

set -uo pipefail

OPENCLAW_HOME="${HOME}/.openclaw"
LOG="/tmp/openclaw/auto-heal.log"
CRON_FILE="${OPENCLAW_HOME}/cron/jobs.json"
ERR_LOG="${OPENCLAW_HOME}/logs/gateway.err.log"
FAILURES_LOG="${OPENCLAW_HOME}/logs/failures.log"
HEAL_MARKER="/tmp/openclaw/auto-heal-last-run"

mkdir -p /tmp/openclaw

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# ── Log rotation ──
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 300 ]]; then
  tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

log "=== Auto-heal cycle start ==="

HEALS=0

# ─────────────────────────────────────────────────────────────────────────────
# PATTERN 1: Channel errors — fix any "channel": "last" in jobs.json
# ─────────────────────────────────────────────────────────────────────────────
if [[ -f "$CRON_FILE" ]]; then
  CHANNEL_LAST_COUNT=$(grep -c '"channel": "last"' "$CRON_FILE" 2>/dev/null || echo "0")
  if [[ "$CHANNEL_LAST_COUNT" -gt 0 ]]; then
    log "HEAL: Found ${CHANNEL_LAST_COUNT} jobs with 'channel: last'. Fixing to 'telegram'..."
    cp "$CRON_FILE" "${CRON_FILE}.bak.autoheal.$(date +%s)"
    # Replace "channel": "last" with "channel": "telegram", "to": "970413391"
    sed -i '' 's/"channel": "last"/"channel": "telegram", "to": "970413391"/g' "$CRON_FILE"
    HEALS=$((HEALS + 1))
    log "HEALED: Fixed ${CHANNEL_LAST_COUNT} channel configs."
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PATTERN 2: OAuth token errors in gateway log
# ─────────────────────────────────────────────────────────────────────────────
if [[ -f "$ERR_LOG" ]]; then
  TEN_MIN_AGO=$(date -v-10M "+%Y-%m-%dT%H:%M" 2>/dev/null || echo "")
  if [[ -n "$TEN_MIN_AGO" ]]; then
    RECENT_TOKEN_ERRORS=$(tail -200 "$ERR_LOG" 2>/dev/null \
      | awk -v cutoff="$TEN_MIN_AGO" '$0 >= cutoff' \
      | grep -c "invalid_grant\|token.*expired\|OAuth.*failed" 2>/dev/null || echo "0")
    RECENT_TOKEN_ERRORS="${RECENT_TOKEN_ERRORS//[^0-9]/}"

    if [[ "$RECENT_TOKEN_ERRORS" -ge 3 ]]; then
      log "HEAL: ${RECENT_TOKEN_ERRORS} token errors in last 10 min. Running token-keeper..."
      if [[ -f "${OPENCLAW_HOME}/scripts/token-keeper.sh" ]]; then
        bash "${OPENCLAW_HOME}/scripts/token-keeper.sh" >> "$LOG" 2>&1 || true
        HEALS=$((HEALS + 1))
        log "HEALED: Token-keeper executed."
      fi
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PATTERN 3: Cron jobs with 3+ consecutive errors → disable + alert
# ─────────────────────────────────────────────────────────────────────────────
if [[ -f "$CRON_FILE" ]]; then
  # Find jobs with high consecutive errors using python for JSON safety
  PROBLEM_JOBS=$(python3 -c "
import json, sys
try:
    data = json.load(open('$CRON_FILE'))
    for job in data.get('jobs', []):
        state = job.get('state', {})
        errs = state.get('consecutiveErrors', 0)
        if errs >= 3 and job.get('enabled', False):
            print(f\"{job.get('name', 'unknown')}: {errs} errors - {state.get('lastError', 'unknown')}\")
except Exception as e:
    print(f'error: {e}', file=sys.stderr)
" 2>/dev/null || true)

  if [[ -n "$PROBLEM_JOBS" ]]; then
    log "ALERT: Jobs with 3+ consecutive errors:"
    echo "$PROBLEM_JOBS" | while read -r line; do
      log "  - $line"
    done
    # Send Telegram alert
    TG_BOT_TOKEN=$(grep -o '"botToken": "[^"]*"' "${OPENCLAW_HOME}/openclaw.json" | head -1 | cut -d'"' -f4 || true)
    if [[ -n "$TG_BOT_TOKEN" ]]; then
      curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": 970413391, \"text\": \"Auto-Heal: Cron jobs with 3+ errors:\n${PROBLEM_JOBS}\"}" \
        >> "$LOG" 2>&1 || log "WARN: Failed to send Telegram alert"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PATTERN 4: Gateway unresponsive → trigger watchdog
# ─────────────────────────────────────────────────────────────────────────────
GATEWAY_URL="http://127.0.0.1:18789"
TOKEN=$(grep -o '"token": "[^"]*"' "${OPENCLAW_HOME}/openclaw.json" | head -1 | cut -d'"' -f4 2>/dev/null || true)
HTTP_CHECK=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -H "Authorization: Bearer ${TOKEN}" \
  "${GATEWAY_URL}/health" 2>/dev/null || echo "000")

if [[ "$HTTP_CHECK" == "000" ]]; then
  log "HEAL: Gateway unresponsive. Triggering watchdog..."
  if [[ -f "${OPENCLAW_HOME}/scripts/gateway-watchdog.sh" ]]; then
    bash "${OPENCLAW_HOME}/scripts/gateway-watchdog.sh" >> "$LOG" 2>&1 || true
    HEALS=$((HEALS + 1))
    log "HEALED: Watchdog triggered for gateway recovery."
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
date +%s > "$HEAL_MARKER"
log "=== Auto-heal cycle complete: ${HEALS} heal(s) applied ==="
