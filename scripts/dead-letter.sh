#!/bin/bash
# dead-letter.sh — Wrapper for cron jobs that captures failures and alerts via Telegram
# Usage: dead-letter.sh <job-name> <command...>
# Created: 2026-03-27

# Ensure Homebrew binaries are in PATH (cron has a minimal PATH)
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

set -uo pipefail

OPENCLAW_BIN="/opt/homebrew/bin/openclaw"
if [ ! -x "$OPENCLAW_BIN" ]; then
  OPENCLAW_BIN="$(command -v openclaw 2>/dev/null || true)"
fi

if [ -z "$OPENCLAW_BIN" ] || [ ! -x "$OPENCLAW_BIN" ]; then
  echo "openclaw CLI not found" >&2
  exit 127
fi

"$OPENCLAW_BIN" --help >/dev/null 2>&1 || {
  echo "openclaw CLI sanity check failed: $OPENCLAW_BIN" >&2
  exit 127
}

JOB_NAME="${1:-unknown}"
shift || { echo "Usage: dead-letter.sh <job-name> <command...>"; exit 1; }

LOG="$HOME/.openclaw/logs/failures.log"
CHAT_ID="970413391"
CONFIG_PATH="$HOME/.openclaw/openclaw.json"

mkdir -p "$(dirname "$LOG")"

BOT_TOKEN=$(CONFIG_PATH="$CONFIG_PATH" python3 <<'PY' 2>/dev/null
import json, os
path = os.environ["CONFIG_PATH"]
try:
    with open(path) as f:
        cfg = json.load(f)
    telegram = (cfg.get("channels") or {}).get("telegram") or {}
    accounts = telegram.get("accounts") or {}
    account = accounts.get("default") or {}
    token = account.get("botToken")
    if isinstance(token, str):
        print(token)
    elif isinstance(token, dict):
        if token.get("source") == "env":
            env_name = token.get("id")
            if env_name:
                print(os.environ.get(env_name, ""))
except Exception:
    pass
PY
)

# Run the command, capture stderr
stderr_file=$(mktemp)
"$@" 2>"$stderr_file"
exit_code=$?

if [ $exit_code -ne 0 ]; then
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  error_msg=$(head -20 "$stderr_file")

  # Log to failures.log
  echo "[$ts] JOB=$JOB_NAME EXIT=$exit_code ERROR=$error_msg" >> "$LOG"

  # Alert via Telegram
  if [ -n "$BOT_TOKEN" ]; then
    msg="🚨 *Cron Job Failed*

*Job:* $JOB_NAME
*Exit code:* $exit_code
*Time:* $(TZ=Asia/Singapore date '+%Y-%m-%d %H:%M SGT')
*Error:*
\`\`\`
$(printf '%s
' "$error_msg" | head -10)
\`\`\`"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(printf '%s' "$msg" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"), \"parse_mode\": \"Markdown\"}" \
      > /dev/null 2>&1
  fi
fi

rm -f "$stderr_file"
exit $exit_code
