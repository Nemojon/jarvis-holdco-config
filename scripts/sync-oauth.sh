#!/bin/bash
# Syncs Claude Code's OAuth token from macOS keychain to all openclaw agent auth-profiles.
# Run periodically (e.g. every 2 hours) to prevent token expiry failures.

set -euo pipefail

KEYCHAIN_ENTRY="Claude Code-credentials"
AGENTS_DIR="$HOME/.openclaw/agents"
LOG_FILE="/tmp/openclaw/oauth-sync.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# Extract fresh token from Claude Code keychain
CREDS=$(security find-generic-password -s "$KEYCHAIN_ENTRY" -w 2>/dev/null) || {
  log "ERROR: Could not read Claude Code credentials from keychain"
  exit 1
}

ACCESS=$(echo "$CREDS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['claudeAiOauth']['accessToken'])")
REFRESH=$(echo "$CREDS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['claudeAiOauth']['refreshToken'])")
EXPIRES=$(echo "$CREDS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['claudeAiOauth']['expiresAt'])")

if [ -z "$ACCESS" ] || [ -z "$REFRESH" ]; then
  log "ERROR: Empty token extracted from keychain"
  exit 1
fi

# Check if token is actually newer than what's already stored
MAIN_AUTH="$AGENTS_DIR/main/agent/auth-profiles.json"
if [ -f "$MAIN_AUTH" ]; then
  CURRENT_EXPIRES=$(python3 -c "import json; d=json.load(open('$MAIN_AUTH')); print(d.get('profiles',{}).get('anthropic:default',{}).get('expires',0))" 2>/dev/null || echo "0")
  if [ "$EXPIRES" = "$CURRENT_EXPIRES" ]; then
    log "SKIP: Token unchanged (expires=$EXPIRES)"
    exit 0
  fi
fi

# Update all agent auth-profiles.json
UPDATED=0
FAILED=0
for agent_dir in "$AGENTS_DIR"/*/agent; do
  auth_file="$agent_dir/auth-profiles.json"
  [ -f "$auth_file" ] || continue
  agent_name=$(basename "$(dirname "$agent_dir")")

  python3 -c "
import json, sys
with open('$auth_file', 'r') as f:
    data = json.load(f)
p = data.get('profiles', {}).get('anthropic:default')
if not p:
    sys.exit(2)
p['access'] = '$ACCESS'
p['refresh'] = '$REFRESH'
p['expires'] = $EXPIRES
with open('$auth_file', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null

  rc=$?
  if [ $rc -eq 0 ]; then
    UPDATED=$((UPDATED + 1))
  elif [ $rc -eq 2 ]; then
    : # no anthropic profile, skip silently
  else
    FAILED=$((FAILED + 1))
    log "WARN: Failed to update $agent_name"
  fi
done

log "OK: Synced token to $UPDATED agents (expires=$EXPIRES, failed=$FAILED)"

# Also sync to VPS if reachable (non-blocking)
VPS_PASS_FILE="/tmp/vps_pass"
if [ -f "$VPS_PASS_FILE" ]; then
  sshpass -f "$VPS_PASS_FILE" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@187.127.100.204 \
    "python3 -c \"
import json, glob, os
for auth_file in glob.glob('/root/.openclaw/agents/*/agent/auth-profiles.json'):
    with open(auth_file) as f:
        data = json.load(f)
    p = data.get('profiles', {}).get('anthropic:default')
    if not p: continue
    p['access'] = '$ACCESS'
    p['refresh'] = '$REFRESH'
    p['expires'] = $EXPIRES
    with open(auth_file, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\\\n')
print('VPS agents updated')
\"" >> "$LOG_FILE" 2>&1 &
fi
