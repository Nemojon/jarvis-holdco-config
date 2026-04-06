#!/usr/bin/env bash
# brave-with-debug.sh — Launch Brave with remote debugging for OpenClaw
# This ensures OpenClaw can attach to the real Brave browser session

BRAVE_APP="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
PORT=9222
BRAVE_DATA_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
LOG="$HOME/.openclaw/logs/brave-debug.log"

mkdir -p "$(dirname "$LOG")"

# Check if Brave is already running with debug port
if lsof -i :$PORT >/dev/null 2>&1; then
    echo "[$(date)] Brave already running with debug port $PORT" >> "$LOG"
    exit 0
fi

# Kill existing Brave if running without debug port
if pgrep -x "Brave Browser" >/dev/null 2>&1; then
    echo "[$(date)] Killing Brave without debug port..." >> "$LOG"
    pkill -f "Brave Browser"
    sleep 2
fi

# Launch Brave with remote debugging
echo "[$(date)] Launching Brave with --remote-debugging-port=$PORT" >> "$LOG"
open -a "Brave Browser" --args --remote-debugging-port=$PORT

# Wait for CDP to be available
for i in $(seq 1 10); do
    if curl -s http://127.0.0.1:$PORT/json/version >/dev/null 2>&1; then
        echo "[$(date)] Brave CDP ready on port $PORT" >> "$LOG"
        
        # Create DevToolsActivePort file for Chrome MCP discovery
        WS_URL=$(curl -s http://127.0.0.1:$PORT/json/version | python3 -c "import json,sys,re; d=json.load(sys.stdin); m=re.search(r'/devtools/browser/(.*)', d.get('webSocketDebuggerUrl','')); print(f'$PORT\n/devtools/browser/{m.group(1)}') if m else print('$PORT\n')" 2>/dev/null)
        printf "%s\n" "$WS_URL" > "$BRAVE_DATA_DIR/DevToolsActivePort"
        echo "[$(date)] DevToolsActivePort created" >> "$LOG"
        exit 0
    fi
    sleep 1
done

echo "[$(date)] WARNING: Brave started but CDP not responding on port $PORT" >> "$LOG"
exit 1
