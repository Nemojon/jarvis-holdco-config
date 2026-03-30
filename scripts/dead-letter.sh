#!/bin/bash
# dead-letter.sh — Wrapper for cron jobs that captures failures and alerts via Telegram
# Usage: dead-letter.sh <job-name> <command...>
# Created: 2026-03-27

# Ensure Homebrew binaries are in PATH (cron has a minimal PATH)
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

set -uo pipefail

JOB_NAME="${1:-unknown}"
shift || { echo "Usage: dead-letter.sh <job-name> <command...>"; exit 1; }

LOG="$HOME/.openclaw/logs/failures.log"
BOT_TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json'))['channels']['telegram']['botToken'])" 2>/dev/null)
CHAT_ID="970413391"

mkdir -p "$(dirname "$LOG")"

# Run the command, capture stderr
stderr_file=$(mktemp)
"$@" 2>"$stderr_file"
exit_code=$?

if [ $exit_code -ne 0 ]; then
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  error_msg=$(cat "$stderr_file" | head -20)

  # Log to failures.log
  echo "[$ts] JOB=$JOB_NAME EXIT=$exit_code ERROR=$error_msg" >> "$LOG"

  # Alert via Telegram
  if [ -n "$BOT_TOKEN" ]; then
    msg="🚨 *Cron Job Failed*

*Job:* $JOB_NAME
*Exit code:* $exit_code
*Time:* $(date '+%Y-%m-%d %H:%M WITA')
*Error:*
\`\`\`
$(echo "$error_msg" | head -10)
\`\`\`"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo "$msg" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"), \"parse_mode\": \"Markdown\"}" \
      > /dev/null 2>&1
  fi
fi

rm -f "$stderr_file"
exit $exit_code
