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

update_auth_file() {
  local auth_file="$1"
  local tmp_file
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/sync-oauth.XXXXXX")

  if AUTH_FILE="$auth_file" ACCESS="$ACCESS" REFRESH="$REFRESH" EXPIRES="$EXPIRES" TMP_FILE="$tmp_file" python3 - <<'PY' 2>/dev/null
import json, os, sys

auth_file = os.environ['AUTH_FILE']
tmp_file = os.environ['TMP_FILE']
access = os.environ['ACCESS']
refresh = os.environ['REFRESH']
expires = int(os.environ['EXPIRES'])

with open(auth_file, 'r') as f:
    data = json.load(f)

profiles = data.get('profiles', {})
profile = profiles.get('anthropic:default')
if not profile:
    sys.exit(2)

profile['access'] = access
profile['refresh'] = refresh
profile['expires'] = expires

with open(tmp_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PY
  then
    mv "$tmp_file" "$auth_file"
    return 0
  else
    rc=$?
    rm -f "$tmp_file"
    return "$rc"
  fi
}

# Update all agent auth-profiles.json
UPDATED=0
SKIPPED=0
FAILED=0
for agent_dir in "$AGENTS_DIR"/*/agent; do
  auth_file="$agent_dir/auth-profiles.json"
  [ -f "$auth_file" ] || continue
  agent_name=$(basename "$(dirname "$agent_dir")")

  if update_auth_file "$auth_file"; then
    UPDATED=$((UPDATED + 1))
  else
    rc=$?
    if [ $rc -eq 2 ]; then
      SKIPPED=$((SKIPPED + 1))
      log "SKIP: $agent_name has no anthropic:default profile"
    else
      FAILED=$((FAILED + 1))
      log "WARN: Failed to update $agent_name auth profile (rc=$rc)"
    fi
  fi
done

log "OK: Synced token to $UPDATED agents; skipped=$SKIPPED; failed=$FAILED (expires=$EXPIRES)"

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
