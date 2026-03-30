#!/usr/bin/env bash
# =============================================================================
# token-keeper.sh — Proactively refresh Anthropic OAuth token before expiry
#
# Problem: Openclaw gateway uses Anthropic OAuth tokens that last ~8 hours.
# The tokens live in the macOS Keychain, but only get refreshed when Claude Code
# makes an API call. If no Claude Code session is active, the token expires
# and the gateway dies.
#
# Solution: When the token is within 2 hours of expiry, run a minimal Claude
# Code prompt that forces the SDK to refresh the token in the Keychain.
# Then trigger sync-oauth.sh to propagate the fresh token to all agents.
#
# Runs every 30 minutes via launchd.
# =============================================================================

set -uo pipefail

LOG="/tmp/openclaw/token-keeper.log"
SYNC_LOG="/tmp/openclaw/oauth-sync.log"
OPENCLAW_HOME="${HOME}/.openclaw"
MAX_LOG_LINES=200
REFRESH_WINDOW=7200  # 2 hours in seconds

mkdir -p /tmp/openclaw

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# ── Log rotation ────────────────────────────────────────────────────────────
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt "$MAX_LOG_LINES" ]]; then
  tail -"$MAX_LOG_LINES" "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# ── Read current token expiry ────────────────────────────────────────────────
EXPIRES_MS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['claudeAiOauth']['expiresAt'])" 2>/dev/null || echo "0")

if [[ "$EXPIRES_MS" == "0" ]]; then
  log "WARN: Cannot read token from Keychain. Skipping."
  exit 0
fi

EXPIRES_S=$(( EXPIRES_MS / 1000 ))
NOW_S=$(date +%s)
REMAINING=$(( EXPIRES_S - NOW_S ))
REMAINING_H=$(python3 -c "print(f'{${REMAINING}/3600:.1f}')")

if [[ "$REMAINING" -gt "$REFRESH_WINDOW" ]]; then
  log "OK: Token valid for ${REMAINING_H}h (${REMAINING}s). No refresh needed."
  exit 0
fi

if [[ "$REMAINING" -lt 0 ]]; then
  log "CRITICAL: Token already expired ${REMAINING}s ago. Forcing refresh..."
else
  log "REFRESH: Token expires in ${REMAINING_H}h (${REMAINING}s). Triggering refresh..."
fi

# ── Force token refresh via minimal Claude Code API call ─────────────────────
# This makes the Claude Code SDK check the token, see it's near expiry,
# and use the refresh_token to get a new access_token from Anthropic.
OLD_EXPIRY="$EXPIRES_MS"

REFRESH_OUTPUT=$(echo "say ok" | timeout 30 claude -p "reply with just the word ok" --max-turns 1 2>&1 || echo "CLAUDE_FAILED")

if echo "$REFRESH_OUTPUT" | grep -q "CLAUDE_FAILED\|error\|Error"; then
  log "WARN: Claude Code refresh call failed: $(echo "$REFRESH_OUTPUT" | head -1)"
  # Even if the prompt failed, the SDK may have refreshed the token
fi

# ── Check if token actually changed ──────────────────────────────────────────
NEW_EXPIRES_MS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['claudeAiOauth']['expiresAt'])" 2>/dev/null || echo "0")

if [[ "$NEW_EXPIRES_MS" != "$OLD_EXPIRY" && "$NEW_EXPIRES_MS" != "0" ]]; then
  NEW_REMAINING=$(( NEW_EXPIRES_MS / 1000 - $(date +%s) ))
  NEW_REMAINING_H=$(python3 -c "print(f'{${NEW_REMAINING}/3600:.1f}')")
  log "SUCCESS: Token refreshed. New expiry in ${NEW_REMAINING_H}h (was ${REMAINING_H}h)."

  # Propagate new token to all agents
  if [[ -f "${OPENCLAW_HOME}/scripts/sync-oauth.sh" ]]; then
    bash "${OPENCLAW_HOME}/scripts/sync-oauth.sh" >> "$LOG" 2>&1 || true
    log "Token synced to agents."
  fi

  # Restart gateway to pick up new token
  openclaw gateway restart >> "$LOG" 2>&1 || true
  log "Gateway restarted with fresh token."
else
  log "WARN: Token did not change after refresh attempt (expiry still ${REMAINING_H}h). Claude Code may not have been able to refresh."
fi
