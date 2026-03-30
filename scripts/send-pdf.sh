#!/bin/bash
# send-pdf.sh — Convert markdown to styled PDF and send via Telegram
# Usage: send-pdf.sh <markdown-file> <telegram-caption> [chat-id]
#
# Example: send-pdf.sh /path/to/report.md "📄 Morning Intel Report" 970413391

set -uo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

MD_FILE="${1:?Usage: send-pdf.sh <markdown-file> <caption> [chat-id]}"
CAPTION="${2:?Usage: send-pdf.sh <markdown-file> <caption> [chat-id]}"
CHAT_ID="${3:-970413391}"

# Skip if source file doesn't exist
if [ ! -f "$MD_FILE" ]; then
  echo "File not found: $MD_FILE — skipping"
  exit 0
fi

# Generate PDF
PDF_FILE="/tmp/openclaw-report-$(date +%s).pdf"
cat "$MD_FILE" | md-to-pdf > "$PDF_FILE" 2>/dev/null

if [ ! -f "$PDF_FILE" ] || [ ! -s "$PDF_FILE" ]; then
  echo "PDF generation failed for $MD_FILE"
  exit 1
fi

# Send via Telegram
openclaw message send --channel telegram --target "$CHAT_ID" \
  -m "$CAPTION" --media "$PDF_FILE" --force-document 2>/dev/null

# Cleanup
rm -f "$PDF_FILE"
echo "Sent: $CAPTION"
