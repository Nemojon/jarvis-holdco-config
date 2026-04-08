#!/usr/bin/env bash
# =============================================================================
# notion-bridge.sh — Bridge for Openclaw agents to write to Notion via Cortex
#
# Usage: bash notion-bridge.sh "read|write" "vault|playbooks" "content"
#
# Actions:
#   read vault     — Read the Knowledge Vault
#   read playbooks — Read Playbooks & SOPs
#   write vault "YYYY-MM-DD | Agent | Knowledge entry"    — Add to Knowledge Vault
#   write playbooks "Title" "Steps content"                — Add to Playbooks
# =============================================================================

set -uo pipefail

ACTION="${1:-}"
TARGET="${2:-}"
CONTENT="${3:-}"
EXTRA="${4:-}"
LOG="/tmp/openclaw/notion-bridge.log"

mkdir -p /tmp/openclaw

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

if [ -z "$ACTION" ] || [ -z "$TARGET" ]; then
  echo "Usage: notion-bridge.sh read|write vault|playbooks [content]"
  exit 1
fi

VAULT_ID="33b6c4f2ff1d81a8b8acc60562457dc1"
PLAYBOOKS_ID="33b6c4f2ff1d8193b870f73c1d1d4c84"

if [ "$TARGET" = "vault" ]; then
  PAGE_ID="$VAULT_ID"
elif [ "$TARGET" = "playbooks" ]; then
  PAGE_ID="$PLAYBOOKS_ID"
else
  echo "ERROR: target must be 'vault' or 'playbooks'"
  exit 1
fi

log "NOTION BRIDGE: action=$ACTION target=$TARGET"

# Route through Cortex bridge
if [ "$ACTION" = "read" ]; then
  TASK="Read the Notion page https://www.notion.so/$PAGE_ID and return its full content as clean text."
elif [ "$ACTION" = "write" ]; then
  if [ -z "$CONTENT" ]; then
    echo "ERROR: write requires content"
    exit 1
  fi
  TASK="Add this entry to the Notion Knowledge Vault (https://www.notion.so/$PAGE_ID). Append it under the appropriate category section. Entry: $CONTENT"
else
  echo "ERROR: action must be 'read' or 'write'"
  exit 1
fi

RESULT=$(timeout 120 claude -p "$TASK" --output-format text 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  log "NOTION BRIDGE SUCCESS"
  echo "$RESULT"
else
  log "NOTION BRIDGE FAILED: exit=$EXIT_CODE"
  echo "NOTION BRIDGE ERROR: exit=$EXIT_CODE output=$RESULT"
fi
