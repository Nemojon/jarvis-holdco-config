#!/bin/bash
# hello-cortex.sh — Jon's morning startup sequence
# Triggered by: running `hello-cortex` from terminal
# What it does:
#   1. Pre-flight: checks gateway health + auto-approves pending device repairs
#   2. Nova pings Jon good morning on Telegram (async, free-form)
#   3. Jarvis pings Jon good morning on Telegram (async, free-form)
#   4. Opens Claude Code Session 1: Morning Briefing
#   5. Opens Claude Code Session 2: Overnight Openclaw Report

OPENCLAW_DIR="$HOME/vps-backup-2026-03-31/openclaw"

echo "☀️  Good morning, Jon. Cortex is waking up the fleet..."

# --- 0. Pre-flight: auto-approve pending device repairs ---
PENDING=$(openclaw devices list --json 2>/dev/null | python3 -c "
import sys, json
try:
    lines = sys.stdin.read()
    start = lines.find('{')
    data = json.loads(lines[start:])
    pending = data.get('pending', [])
    if pending:
        print('yes')
    else:
        print('no')
except:
    print('no')
" 2>/dev/null)

if [ "$PENDING" = "yes" ]; then
    echo "→ Auto-approving pending device repair..."
    openclaw devices approve --latest 2>/dev/null && echo "  ✓ Device re-paired" || echo "  ⚠ Could not auto-approve, may need manual pairing"
fi

# --- 1. Nova (apex) Telegram ping — async ---
echo "→ Pinging Nova..."
openclaw agent --agent apex -m "Good morning Nova. Ping Jon good morning on Telegram right now. Share whatever is on your mind — strategy insights, quality observations, anything from your overnight research or analysis that Jon should know. Be natural, be yourself. Don't wait for instructions, just greet him and share what matters." >/dev/null 2>&1 &
NOVA_PID=$!

# --- 2. Jarvis (orion) Telegram ping — async ---
echo "→ Pinging Jarvis..."
openclaw agent --agent orion -m "Good morning Jarvis. Ping Jon good morning on Telegram right now. Share whatever is on your mind — operational updates, fleet status, overnight findings, priorities for today. Be natural, be yourself. Don't wait for instructions, just greet him and share what matters." >/dev/null 2>&1 &
JARVIS_PID=$!

echo "→ Nova and Jarvis are composing their messages..."

# --- 3. Claude Code Session 1: Morning Briefing ---
echo "→ Opening Claude Code — Morning Briefing..."
claude --add-dir "$OPENCLAW_DIR" -p "Morning Cortex. Run the full morning briefing protocol." &

# --- 4. Claude Code Session 2: Overnight Openclaw Report ---
echo "→ Opening Claude Code — Overnight Report..."
claude --add-dir "$OPENCLAW_DIR" -p "Run a detailed overnight report on the Openclaw system. Cover: (1) All agent activity from last night — check ~/.openclaw/workspace-*/memory/ for overnight logs, (2) Cron job execution results — check ~/.openclaw/cron/jobs.json and /tmp/openclaw/ logs, (3) Gateway health — tail ~/.openclaw/logs/gateway.log and gateway.err.log for overnight entries, (4) Any errors, stuck agents, or anomalies, (5) Summary of what each agent did while Jon was sleeping. Format as a clean report." &

# Wait for agent pings to finish (timeout 90s)
TIMEOUT=90
( sleep $TIMEOUT && kill $NOVA_PID $JARVIS_PID 2>/dev/null ) &
WATCHDOG=$!
wait $NOVA_PID 2>/dev/null
wait $JARVIS_PID 2>/dev/null
kill $WATCHDOG 2>/dev/null

echo ""
echo "✅ Fleet is awake. Nova and Jarvis have pinged Telegram."
echo "✅ Two Claude Code sessions are running."
echo ""
echo "Have a great day, boss."
