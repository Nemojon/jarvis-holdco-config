#!/usr/bin/env bash
# =============================================================================
# sync-to-vps.sh — Lightweight config sync from Mac mini to VPS hot standby
# Designed for frequent automated runs via launchd (every 30 min).
# No interactive prompts, no PM2 restarts (unless tokens changed).
# =============================================================================

set -uo pipefail

VPS_IP="187.127.100.204"
VPS_USER="root"
SSH_KEY="/Users/apex/.ssh/vps_hostinger"
REMOTE="${VPS_USER}@${VPS_IP}"

MAC_OPENCLAW="${HOME}/.openclaw"
VPS_OPENCLAW="/root/.openclaw"

LOG="/tmp/openclaw/vps-sync.log"
MAX_LOG_LINES=200

SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"
RSYNC_SSH="ssh ${SSH_OPTS}"

mkdir -p /tmp/openclaw

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# ── Log rotation ────────────────────────────────────────────────────────────
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt "$MAX_LOG_LINES" ]]; then
  tail -"$MAX_LOG_LINES" "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

log "--- Sync started ---"

# ── Pre-flight: check SSH connectivity ──────────────────────────────────────
if ! ssh ${SSH_OPTS} "${REMOTE}" "echo ok" >/dev/null 2>&1; then
  log "ERROR: Cannot reach VPS via SSH. Aborting."
  exit 1
fi

# ── Ensure remote dirs exist ────────────────────────────────────────────────
ssh ${SSH_OPTS} "${REMOTE}" "mkdir -p ${VPS_OPENCLAW}/{agents,workspace-orion,vault,cron}" 2>/dev/null

# ── Common rsync options ────────────────────────────────────────────────────
RSYNC_BASE=(-az --delete -e "${RSYNC_SSH}")
SYNCED=0
ERRORS=0

do_sync() {
  local src="$1" dst="$2" label="$3"
  shift 3
  # remaining args are extra rsync flags (--exclude, etc.)
  if [[ ! -e "$src" ]]; then
    log "SKIP: ${label} — source not found: ${src}"
    return
  fi
  if rsync "${RSYNC_BASE[@]}" "$@" "${src}" "${REMOTE}:${dst}" >> "$LOG" 2>&1; then
    SYNCED=$((SYNCED + 1))
    log "OK: ${label}"
  else
    ERRORS=$((ERRORS + 1))
    log "FAIL: ${label}"
  fi
}

# ── 1. openclaw.json ────────────────────────────────────────────────────────
# SKIP: VPS has its own openclaw.json with Telegram enabled and VPS-specific
# paths. Syncing Mac mini's config would overwrite VPS Telegram/plugin settings.
# VPS config is managed independently.
log "SKIP: openclaw.json — VPS has its own config (Telegram primary)"

# ── 2. agents/ ──────────────────────────────────────────────────────────────
do_sync "${MAC_OPENCLAW}/agents/" "${VPS_OPENCLAW}/agents/" "agents" \
  --exclude='node_modules/' \
  --exclude='.DS_Store' \
  --exclude='sessions/' \
  --exclude='__pycache__/' \
  --exclude='*.log'

# ── 3. All workspaces ──────────────────────────────────────────────────────
for ws_dir in "${MAC_OPENCLAW}"/workspace-*/; do
  ws_name=$(basename "$ws_dir")
  do_sync "${ws_dir}" "${VPS_OPENCLAW}/${ws_name}/" "$ws_name" \
    --exclude='.git/' \
    --exclude='.DS_Store' \
    --exclude='node_modules/' \
    --exclude='*.log'
done

# ── 4. scripts/ ─────────────────────────────────────────────────────────────
do_sync "${MAC_OPENCLAW}/scripts/" "${VPS_OPENCLAW}/scripts/" "scripts" \
  --exclude='.DS_Store'

# ── 5. vault/ ───────────────────────────────────────────────────────────────
do_sync "${MAC_OPENCLAW}/vault/" "${VPS_OPENCLAW}/vault/" "vault" \
  --exclude='.DS_Store'

# ── 6. cron/ (if exists) ───────────────────────────────────────────────────
if [[ -d "${MAC_OPENCLAW}/cron" ]]; then
  do_sync "${MAC_OPENCLAW}/cron/" "${VPS_OPENCLAW}/cron/" "cron" \
    --exclude='.DS_Store'
fi

# ── 6. Token sync: check if auth-profiles changed, restart gateway if so ───
# Snapshot a representative auth-profile hash before/after sync
TOKENS_CHANGED=0
VPS_TOKEN_HASH_BEFORE=$(ssh ${SSH_OPTS} "${REMOTE}" \
  "md5sum /root/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null | cut -d' ' -f1" 2>/dev/null || echo "none")

# The agents/ sync above already pushed fresh auth-profiles. Now check if it changed.
VPS_TOKEN_HASH_AFTER=$(ssh ${SSH_OPTS} "${REMOTE}" \
  "md5sum /root/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null | cut -d' ' -f1" 2>/dev/null || echo "none")

if [[ "$VPS_TOKEN_HASH_BEFORE" != "$VPS_TOKEN_HASH_AFTER" ]] || [[ "$VPS_TOKEN_HASH_BEFORE" == "none" ]]; then
  TOKENS_CHANGED=1
fi

# If tokens changed, restart the openclaw gateway on VPS via pm2
if [[ "$TOKENS_CHANGED" -eq 1 ]]; then
  log "TOKENS CHANGED: Restarting openclaw gateway on VPS..."
  ssh ${SSH_OPTS} "${REMOTE}" "
    if command -v pm2 >/dev/null 2>&1 && pm2 list 2>/dev/null | grep -q openclaw; then
      pm2 reload openclaw --update-env 2>&1
      echo 'Gateway reloaded'
    else
      echo 'No openclaw pm2 process found — skipping restart'
    fi
  " >> "$LOG" 2>&1 || log "WARN: VPS gateway restart failed"
  log "VPS gateway restart complete."
else
  log "Tokens unchanged — no VPS gateway restart needed."
fi

# ── Summary ─────────────────────────────────────────────────────────────────
log "--- Sync finished: ${SYNCED} synced, ${ERRORS} errors, tokens_changed=${TOKENS_CHANGED} ---"
