#!/bin/bash
# browser-watchdog.sh — Hourly check: close stale tabs + close Brave if inactive
# Stale = any tab that isn't about:blank or actively needed
# Inactive = browser running but no active CDP clients connected

LOG="/tmp/openclaw/browser-watchdog.log"
mkdir -p /tmp/openclaw

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# Check if Brave is running
BRAVE_PID=$(pgrep -f "Brave Browser.*--remote-debugging-port" | head -1)
if [ -z "$BRAVE_PID" ]; then
  log "Browser not running. Nothing to do."
  exit 0
fi

log "Brave running (PID $BRAVE_PID). Checking activity..."

# --- PHASE 1: Clean stale tabs ---
TAB_COUNT=$(osascript -e 'tell application "Brave Browser" to count of tabs of window 1' 2>/dev/null)
if [ -n "$TAB_COUNT" ] && [ "$TAB_COUNT" -gt 1 ]; then
  log "Found $TAB_COUNT tabs. Cleaning stale tabs..."
  osascript -e '
    tell application "Brave Browser"
      tell window 1
        set tabCount to count of tabs
        -- Close from last to first to avoid index shifting
        repeat while tabCount > 1
          close tab tabCount
          set tabCount to tabCount - 1
        end repeat
        -- Set remaining tab to blank
        set URL of tab 1 to "about:blank"
      end tell
    end tell' 2>/dev/null
  NEW_COUNT=$(osascript -e 'tell application "Brave Browser" to count of tabs of window 1' 2>/dev/null)
  log "Tab cleanup complete: $TAB_COUNT -> ${NEW_COUNT:-1} tabs."
elif [ "$TAB_COUNT" -eq 1 ]; then
  # Check if the single tab is stale (not blank)
  TAB_URL=$(osascript -e 'tell application "Brave Browser" to get URL of active tab of window 1' 2>/dev/null)
  if [ "$TAB_URL" != "about:blank" ] && [ -n "$TAB_URL" ]; then
    osascript -e 'tell application "Brave Browser" to set URL of active tab of window 1 to "about:blank"' 2>/dev/null
    log "Reset single stale tab to blank (was: $TAB_URL)"
  fi
fi

# --- PHASE 2: Check if browser should be fully closed ---
# Check for active CDP WebSocket connections on port 9222
ACTIVE_CONNECTIONS=$(lsof -i :9222 -sTCP:ESTABLISHED 2>/dev/null | grep -v "^COMMAND" | wc -l | tr -d ' ')

# Also check if any openclaw agent instances are currently running
AGENT_INSTANCES=$(curl -s http://localhost:18789/api/instances 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    instances = data if isinstance(data, list) else data.get('instances', [])
    print(len(instances))
except:
    print('0')
" 2>/dev/null)

log "Active CDP connections: $ACTIVE_CONNECTIONS | Running agent instances: $AGENT_INSTANCES"

# Only close if NO active CDP connections AND no running agents
if [ "$ACTIVE_CONNECTIONS" -eq 0 ] && [ "${AGENT_INSTANCES:-0}" -eq 0 ]; then
  log "Browser INACTIVE — no CDP connections, no running agents. Closing Brave."
  osascript -e 'tell application "Brave Browser" to quit' 2>/dev/null
  sleep 2
  # Force kill if still running
  if pgrep -f "Brave Browser" > /dev/null 2>&1; then
    log "Graceful quit failed, force killing..."
    pkill -f "Brave Browser"
  fi
  log "Brave closed."
elif [ "$ACTIVE_CONNECTIONS" -eq 0 ] && [ "${AGENT_INSTANCES:-0}" -gt 0 ]; then
  log "Browser has no CDP connections but agents are running — keeping alive (agents may need it)."
else
  log "Browser ACTIVE — $ACTIVE_CONNECTIONS CDP connections. Keeping alive."
fi

# Rotate log if > 1MB
if [ -f "$LOG" ] && [ $(stat -f%z "$LOG" 2>/dev/null || echo 0) -gt 1048576 ]; then
  tail -100 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  log "Log rotated."
fi
