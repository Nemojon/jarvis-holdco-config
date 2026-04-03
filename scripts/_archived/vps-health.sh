#!/usr/bin/env bash
# =============================================================================
# vps-health.sh — Monitor VPS hot standby health
# Checks SSH reachability, openclaw gateway (pm2), jarvis-voice (port 3800).
# Auto-starts gateway if down. Sends Telegram alert if VPS unreachable.
# Runs every 15 minutes via launchd.
# =============================================================================

set -uo pipefail

VPS_IP="187.127.100.204"
VPS_USER="root"
SSH_KEY="/Users/apex/.ssh/vps_hostinger"
REMOTE="${VPS_USER}@${VPS_IP}"

OPENCLAW_HOME="${HOME}/.openclaw"
LOG="/tmp/openclaw/vps-health.log"
MAX_LOG_LINES=200
CHAT_ID="970413391"

SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"

mkdir -p /tmp/openclaw

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# ── Log rotation ────────────────────────────────────────────────────────────
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt "$MAX_LOG_LINES" ]]; then
  tail -"$MAX_LOG_LINES" "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# ── Get Telegram bot token ──────────────────────────────────────────────────
BOT_TOKEN=$(python3 -c "import json; print(json.load(open('${OPENCLAW_HOME}/openclaw.json'))['channels']['telegram']['botToken'])" 2>/dev/null || echo "")

send_telegram() {
  local msg="$1"
  if [[ -z "$BOT_TOKEN" ]]; then
    log "WARN: No Telegram bot token — cannot send alert."
    return
  fi
  local payload
  payload=$(python3 -c "import json,sys; print(json.dumps({'chat_id': '${CHAT_ID}', 'text': sys.argv[1], 'parse_mode': 'Markdown'}))" "$msg" 2>/dev/null)
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null 2>&1 || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 1: SSH reachability
# ═══════════════════════════════════════════════════════════════════════════════
if ! ssh ${SSH_OPTS} "${REMOTE}" "echo ok" >/dev/null 2>&1; then
  log "CRITICAL: VPS ${VPS_IP} unreachable via SSH."
  send_telegram "*VPS UNREACHABLE*

$(date '+%Y-%m-%d %H:%M WITA')

VPS \`${VPS_IP}\` is not responding to SSH.
Hot standby is DOWN."
  exit 1
fi
log "OK: SSH reachable."

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 2: Openclaw gateway via pm2
# ═══════════════════════════════════════════════════════════════════════════════
GATEWAY_STATUS=$(ssh ${SSH_OPTS} "${REMOTE}" "
  if command -v pm2 >/dev/null 2>&1; then
    pm2 list 2>/dev/null | grep -i openclaw | head -1
  else
    echo 'PM2_NOT_FOUND'
  fi
" 2>/dev/null || echo "SSH_ERROR")

if echo "$GATEWAY_STATUS" | grep -qi "online"; then
  log "OK: Openclaw gateway running on VPS."
elif echo "$GATEWAY_STATUS" | grep -qi "PM2_NOT_FOUND"; then
  log "WARN: pm2 not installed on VPS."
elif echo "$GATEWAY_STATUS" | grep -qi "stopped\|errored"; then
  log "WARN: Openclaw gateway stopped/errored on VPS. Attempting restart..."
  RESTART_OUT=$(ssh ${SSH_OPTS} "${REMOTE}" "
    pm2 restart openclaw --update-env 2>&1 || pm2 start /root/.openclaw/ecosystem.config.js 2>&1
  " 2>/dev/null || echo "RESTART_FAILED")
  log "Gateway restart attempt: ${RESTART_OUT}"
elif [[ -z "$GATEWAY_STATUS" ]] || ! echo "$GATEWAY_STATUS" | grep -qi "openclaw"; then
  log "WARN: Openclaw gateway not found in pm2. Attempting start..."
  START_OUT=$(ssh ${SSH_OPTS} "${REMOTE}" "
    if [[ -f /root/.openclaw/ecosystem.config.js ]]; then
      pm2 start /root/.openclaw/ecosystem.config.js 2>&1
      pm2 save 2>&1
    else
      echo 'No ecosystem.config.js found'
    fi
  " 2>/dev/null || echo "START_FAILED")
  log "Gateway start attempt: ${START_OUT}"
else
  log "WARN: Unknown gateway status: ${GATEWAY_STATUS}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 3: jarvis-voice health (port 3800)
# ═══════════════════════════════════════════════════════════════════════════════
JARVIS_STATUS=$(ssh ${SSH_OPTS} "${REMOTE}" "
  curl -s --max-time 5 http://localhost:3800/health 2>/dev/null || echo 'JARVIS_UNREACHABLE'
" 2>/dev/null || echo "SSH_ERROR")

if echo "$JARVIS_STATUS" | grep -qi "ok\|healthy\|alive"; then
  log "OK: jarvis-voice healthy on VPS."
elif echo "$JARVIS_STATUS" | grep -q "JARVIS_UNREACHABLE"; then
  log "WARN: jarvis-voice not responding on VPS port 3800."
else
  log "INFO: jarvis-voice response: ${JARVIS_STATUS}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# ALL CLEAR
# ═══════════════════════════════════════════════════════════════════════════════
log "--- Health check complete ---"
