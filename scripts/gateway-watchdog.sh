#!/usr/bin/env bash
# =============================================================================
# gateway-watchdog.sh — Auto-recover Openclaw gateway from auth/connectivity
# failures. Runs every 5 minutes via launchd.
#
# Checks (in order):
#   1. Is the gateway process alive?
#   2. Is the gateway responding to HTTP?
#   3. Are there recent OAuth auth failures? (time-windowed, not just tail)
#   4. Is Telegram polling working?
#   5. Is the OAuth token close to expiring?
#   6. Can the gateway actually complete an agent request?
# =============================================================================

set -uo pipefail  # no -e: we handle errors explicitly

LOG="/tmp/openclaw/watchdog.log"
mkdir -p /tmp/openclaw
OPENCLAW_HOME="${HOME}/.openclaw"
GATEWAY_URL="http://127.0.0.1:18789"
TOKEN=$(grep -o '"token": "[^"]*"' "${OPENCLAW_HOME}/openclaw.json" | head -1 | cut -d'"' -f4)
ERR_LOG="${OPENCLAW_HOME}/logs/gateway.err.log"
MAX_AUTH_ERRORS=5
RESTART_COOLDOWN_FILE="/tmp/openclaw/watchdog-last-restart"
COOLDOWN_SECONDS=300
MAX_LOG_LINES=500

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# ── Log rotation: keep last 500 lines ───────────────────────────────────────
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt "$MAX_LOG_LINES" ]]; then
  tail -"$MAX_LOG_LINES" "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# ── Cooldown check helper ───────────────────────────────────────────────────
check_cooldown() {
  if [[ -f "$RESTART_COOLDOWN_FILE" ]]; then
    local last_restart now elapsed
    last_restart=$(cat "$RESTART_COOLDOWN_FILE")
    now=$(date +%s)
    elapsed=$(( now - last_restart ))
    if [[ "$elapsed" -lt "$COOLDOWN_SECONDS" ]]; then
      log "COOLDOWN: Restart needed but cooldown active (${elapsed}s/${COOLDOWN_SECONDS}s). Skipping."
      return 1
    fi
  fi
  return 0
}

# ── Restart helper ───────────────────────────────────────────────────────────
do_restart() {
  local reason="$1"
  if ! check_cooldown; then
    return 1
  fi

  log "RESTARTING: ${reason}"

  # Always refresh tokens before restart
  if [[ -f "${OPENCLAW_HOME}/scripts/sync-oauth.sh" ]]; then
    bash "${OPENCLAW_HOME}/scripts/sync-oauth.sh" >> "$LOG" 2>&1 || true
  fi

  openclaw gateway restart >> "$LOG" 2>&1 || {
    # Fallback: force kill and start
    log "WARN: 'openclaw gateway restart' failed, trying kickstart..."
    launchctl kickstart -k gui/501/ai.openclaw.gateway 2>/dev/null || true
  }

  date +%s > "$RESTART_COOLDOWN_FILE"
  log "RESTARTED: ${reason}"
  return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 1: Is the gateway process alive?
# ═══════════════════════════════════════════════════════════════════════════════
GATEWAY_PID=$(pgrep -f "openclaw.*gateway" 2>/dev/null | head -1 || true)
if [[ -z "$GATEWAY_PID" ]]; then
  log "CRITICAL: Gateway process not found."
  do_restart "process not running"
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 2: Is the gateway responding to HTTP health?
# ═══════════════════════════════════════════════════════════════════════════════
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -H "Authorization: Bearer ${TOKEN}" \
  "${GATEWAY_URL}/health" 2>/dev/null || echo "000")

if [[ "$HTTP_STATUS" == "000" ]]; then
  log "CRITICAL: Gateway not responding (HTTP timeout, PID ${GATEWAY_PID})."
  do_restart "gateway unresponsive (HTTP timeout)"
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 3: Recent OAuth auth failures (time-windowed: last 5 minutes only)
# ═══════════════════════════════════════════════════════════════════════════════
if [[ -f "$ERR_LOG" ]]; then
  FIVE_MIN_AGO=$(date -v-5M "+%Y-%m-%dT%H:%M" 2>/dev/null || date -d "5 minutes ago" "+%Y-%m-%dT%H:%M" 2>/dev/null || echo "")

  if [[ -n "$FIVE_MIN_AGO" ]]; then
    # Only count errors from the last 5 minutes by comparing timestamps
    RECENT_AUTH_ERRORS=$(tail -500 "$ERR_LOG" 2>/dev/null \
      | awk -v cutoff="$FIVE_MIN_AGO" '$0 >= cutoff' \
      | grep -c "OAuth token refresh failed" 2>/dev/null || echo "0")
    RECENT_AUTH_ERRORS="${RECENT_AUTH_ERRORS//[^0-9]/}"
  else
    # Fallback: just check the last 50 lines (roughly last few minutes)
    RECENT_AUTH_ERRORS=$(tail -50 "$ERR_LOG" 2>/dev/null \
      | grep -c "OAuth token refresh failed" 2>/dev/null || echo "0")
    RECENT_AUTH_ERRORS="${RECENT_AUTH_ERRORS//[^0-9]/}"
  fi

  if [[ "$RECENT_AUTH_ERRORS" -ge "$MAX_AUTH_ERRORS" ]]; then
    log "ALERT: ${RECENT_AUTH_ERRORS} OAuth auth failures in last 5 min."
    do_restart "OAuth auth failure spiral (${RECENT_AUTH_ERRORS} errors)"
    exit 0
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 4: Telegram connectivity
# ═══════════════════════════════════════════════════════════════════════════════
if [[ -f "$ERR_LOG" ]]; then
  FIVE_MIN_AGO=$(date -v-5M "+%Y-%m-%dT%H:%M" 2>/dev/null || echo "")
  if [[ -n "$FIVE_MIN_AGO" ]]; then
    RECENT_TG_ERRORS=$(tail -200 "$ERR_LOG" 2>/dev/null \
      | awk -v cutoff="$FIVE_MIN_AGO" '$0 >= cutoff' \
      | grep -c "telegram.*failed\|telegram.*ETIMEDOUT\|telegram.*EHOSTUNREACH" 2>/dev/null || echo "0")
    RECENT_TG_ERRORS="${RECENT_TG_ERRORS//[^0-9]/}"
  else
    RECENT_TG_ERRORS=$(tail -30 "$ERR_LOG" 2>/dev/null \
      | grep -c "telegram.*failed\|telegram.*ETIMEDOUT\|telegram.*EHOSTUNREACH" 2>/dev/null || echo "0")
    RECENT_TG_ERRORS="${RECENT_TG_ERRORS//[^0-9]/}"
  fi

  if [[ "$RECENT_TG_ERRORS" -ge 5 ]]; then
    # Verify Telegram API is actually reachable before restarting
    TG_BOT_TOKEN=$(grep -o '"botToken": "[^"]*"' "${OPENCLAW_HOME}/openclaw.json" | head -1 | cut -d'"' -f4 || true)
    if [[ -n "$TG_BOT_TOKEN" ]]; then
      TG_CHECK=$(curl -s --max-time 5 "https://api.telegram.org/bot${TG_BOT_TOKEN}/getMe" 2>/dev/null | grep -c '"ok":true' || echo "0")
      if [[ "$TG_CHECK" == "1" ]]; then
        # Telegram API is reachable but gateway can't connect — restart
        log "ALERT: ${RECENT_TG_ERRORS} Telegram errors but API is reachable. Gateway stuck."
        do_restart "Telegram polling stuck (${RECENT_TG_ERRORS} errors, API reachable)"
        exit 0
      else
        log "WARN: ${RECENT_TG_ERRORS} Telegram errors and API unreachable. Network issue — not restarting."
      fi
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 5: Token expiry — proactive refresh if <30 min remaining
# Key insight: sync-oauth.sh only copies from Keychain, it doesn't force a
# refresh. If the Keychain token is also stale, restarting won't help.
# So we: sync, re-read the expiry, and only restart if the token actually
# changed (i.e., a fresh token was obtained). Otherwise, just log a warning.
# ═══════════════════════════════════════════════════════════════════════════════
SYNC_LOG="/tmp/openclaw/oauth-sync.log"
TOKEN_REFRESH_MARKER="/tmp/openclaw/watchdog-last-token-expiry"

if [[ -f "$SYNC_LOG" ]]; then
  EXPIRES_LINE=$(tail -10 "$SYNC_LOG" | grep -o "expires=[0-9]*" | tail -1 || true)
  if [[ -n "$EXPIRES_LINE" ]]; then
    EXPIRES_MS="${EXPIRES_LINE#expires=}"
    EXPIRES_S=$(( EXPIRES_MS / 1000 ))
    NOW_S=$(date +%s)
    REMAINING=$(( EXPIRES_S - NOW_S ))

    if [[ "$REMAINING" -lt 1800 ]]; then
      # Read the expiry BEFORE syncing
      OLD_EXPIRY="$EXPIRES_MS"

      # Try to sync fresh tokens from Keychain
      if [[ -f "${OPENCLAW_HOME}/scripts/sync-oauth.sh" ]]; then
        bash "${OPENCLAW_HOME}/scripts/sync-oauth.sh" >> "$LOG" 2>&1 || true
      fi

      # Read the expiry AFTER syncing
      NEW_EXPIRES_LINE=$(tail -5 "$SYNC_LOG" | grep -o "expires=[0-9]*" | tail -1 || true)
      NEW_EXPIRY="${NEW_EXPIRES_LINE#expires=}"

      if [[ "$NEW_EXPIRY" != "$OLD_EXPIRY" && -n "$NEW_EXPIRY" ]]; then
        # Token actually refreshed — restart to pick it up
        log "TOKEN REFRESHED: ${OLD_EXPIRY} → ${NEW_EXPIRY}. Restarting gateway."
        do_restart "OAuth token refreshed (was ${REMAINING}s from expiry)"
        exit 0
      else
        # Token is STILL the same stale one — Keychain hasn't refreshed yet.
        # Don't restart in a loop. Just warn.
        LAST_WARNED=$(cat "$TOKEN_REFRESH_MARKER" 2>/dev/null || echo "0")
        if [[ "$LAST_WARNED" != "$OLD_EXPIRY" ]]; then
          log "WARN: Token expires in ${REMAINING}s but Keychain token unchanged. Cannot refresh — waiting for Claude Code or browser to refresh it."
          echo "$OLD_EXPIRY" > "$TOKEN_REFRESH_MARKER"
        fi

        if [[ "$REMAINING" -lt 0 ]]; then
          # Token fully expired — one restart attempt in case gateway can refresh on its own
          if [[ "$LAST_WARNED" != "expired-${OLD_EXPIRY}" ]]; then
            log "CRITICAL: Token expired ${REMAINING}s ago. One restart attempt."
            echo "expired-${OLD_EXPIRY}" > "$TOKEN_REFRESH_MARKER"
            do_restart "OAuth token expired (${REMAINING}s ago)"
          fi
        fi
        # Don't exit — continue to other checks
      fi
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 6: Liveness — can the gateway actually serve an agent request?
# Run this less frequently (only every 3rd cycle = ~15 min) to avoid cost.
#
# IMPORTANT: After a restart, Telegram shows "configured" (not "ok") for up to
# 2 minutes while the provider connects. We must not restart during this grace
# period or we create an infinite restart loop.
# ═══════════════════════════════════════════════════════════════════════════════
LIVENESS_COUNTER_FILE="/tmp/openclaw/watchdog-liveness-counter"
LIVENESS_COUNT=$(cat "$LIVENESS_COUNTER_FILE" 2>/dev/null || echo "0")
LIVENESS_COUNT=$(( LIVENESS_COUNT + 1 ))
echo "$LIVENESS_COUNT" > "$LIVENESS_COUNTER_FILE"

if [[ $(( LIVENESS_COUNT % 3 )) -eq 0 ]]; then
  # Check how long the gateway has been up — skip liveness if <3 minutes
  GATEWAY_START=$(ps -o lstart= -p "$GATEWAY_PID" 2>/dev/null || true)
  if [[ -n "$GATEWAY_START" ]]; then
    GATEWAY_START_EPOCH=$(date -j -f "%a %b %d %T %Y" "$GATEWAY_START" "+%s" 2>/dev/null || echo "0")
    GATEWAY_UPTIME=$(( $(date +%s) - GATEWAY_START_EPOCH ))
    if [[ "$GATEWAY_UPTIME" -lt 180 ]]; then
      log "OK: Skipping liveness check — gateway only up ${GATEWAY_UPTIME}s (<3min grace)."
    else
      HEALTH_OUTPUT=$(openclaw health 2>&1 || true)
      TG_STATUS=$(echo "$HEALTH_OUTPUT" | grep -i "^Telegram:" || echo "Telegram: unknown")

      if echo "$TG_STATUS" | grep -q "ok"; then
        log "OK: Liveness passed. ${TG_STATUS}"
      elif echo "$TG_STATUS" | grep -q "configured"; then
        # "configured" means Telegram is enabled but provider is still connecting.
        # This is normal during startup. Don't restart — just warn.
        log "WARN: Telegram shows 'configured' (still connecting). Uptime: ${GATEWAY_UPTIME}s. Not restarting."
      else
        log "WARN: Telegram unhealthy: ${TG_STATUS}. Restarting."
        do_restart "Telegram unhealthy on liveness check: ${TG_STATUS}"
        exit 0
      fi
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 7: Disk space monitoring
# ═══════════════════════════════════════════════════════════════════════════════
DISK_USAGE_PCT=$(df -h / | awk 'NR==2 {gsub(/%/,""); print $5}')
DISK_USAGE_PCT="${DISK_USAGE_PCT//[^0-9]/}"

if [[ -n "$DISK_USAGE_PCT" ]]; then
  if [[ "$DISK_USAGE_PCT" -ge 95 ]]; then
    log "CRITICAL: Disk usage at ${DISK_USAGE_PCT}%!"
    TG_BOT_TOKEN=$(grep -o '"botToken": "[^"]*"' "${OPENCLAW_HOME}/openclaw.json" | head -1 | cut -d'"' -f4 || true)
    if [[ -n "$TG_BOT_TOKEN" ]]; then
      curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": 970413391, \"text\": \"\u26a0\ufe0f DISK ALERT: Mac mini at ${DISK_USAGE_PCT}% disk usage\"}" \
        >> "$LOG" 2>&1 || log "WARN: Failed to send Telegram disk alert"
    fi
  elif [[ "$DISK_USAGE_PCT" -ge 85 ]]; then
    log "WARNING: Disk usage at ${DISK_USAGE_PCT}%."
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 8: Cron job health — surface jobs with consecutive errors
# ═══════════════════════════════════════════════════════════════════════════════
CRON_FILE="${OPENCLAW_HOME}/cron/jobs.json"
if [[ -f "$CRON_FILE" ]]; then
  # Count jobs with 2+ consecutive errors
  FAILING_JOBS=$(grep -o '"consecutiveErrors": [0-9]*' "$CRON_FILE" 2>/dev/null \
    | awk -F': ' '$2 >= 2 {count++} END {print count+0}')
  if [[ "$FAILING_JOBS" -gt 0 ]]; then
    log "WARN: ${FAILING_JOBS} cron job(s) have 2+ consecutive errors."
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9: Brave CDP port (9222) — needed for browser-dependent agents
# Run infrequently (every 6th cycle = ~30 min)
# ═══════════════════════════════════════════════════════════════════════════════
if [[ $(( LIVENESS_COUNT % 6 )) -eq 0 ]]; then
  BRAVE_CDP=$(curl -s --max-time 3 "http://127.0.0.1:9222/json/version" 2>/dev/null || echo "")
  if [[ -z "$BRAVE_CDP" ]]; then
    log "WARN: Brave CDP port 9222 not responding. Browser-dependent agents may fail."
  else
    log "OK: Brave CDP port 9222 responding."
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# ALL CLEAR
# ═══════════════════════════════════════════════════════════════════════════════
log "OK: All checks passed (HTTP ${HTTP_STATUS}, PID ${GATEWAY_PID})."
