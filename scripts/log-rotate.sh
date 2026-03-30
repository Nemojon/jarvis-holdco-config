#!/usr/bin/env bash
# =============================================================================
# log-rotate.sh — Rotate Openclaw gateway logs and clean up temp/session files.
# Runs every 6 hours via launchd (ai.openclaw.log-rotate).
# =============================================================================

set -uo pipefail

OPENCLAW_HOME="${HOME}/.openclaw"
LOG_DIR="${OPENCLAW_HOME}/logs"
TMP_DIR="/tmp/openclaw"
ROTATE_LOG="${TMP_DIR}/log-rotate.log"
MAX_SIZE_BYTES=$((5 * 1024 * 1024))       # 5MB for gateway logs
TMP_MAX_SIZE_BYTES=$((1 * 1024 * 1024))   # 1MB for /tmp logs
KEEP_ROTATIONS=3

mkdir -p "$TMP_DIR"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >> "$ROTATE_LOG"; }

# ── Keep rotate log itself small ──────────────────────────────────────────────
if [[ -f "$ROTATE_LOG" ]] && [[ $(wc -l < "$ROTATE_LOG") -gt 200 ]]; then
  tail -100 "$ROTATE_LOG" > "${ROTATE_LOG}.tmp" && mv "${ROTATE_LOG}.tmp" "$ROTATE_LOG"
fi

log "=== Log rotation started ==="

# ── Helper: rotate a single log file ─────────────────────────────────────────
# Usage: rotate_file <path> <max_bytes> <keep_count>
rotate_file() {
  local file="$1"
  local max_bytes="$2"
  local keep="$3"

  if [[ ! -f "$file" ]]; then
    return
  fi

  local size
  size=$(stat -f%z "$file" 2>/dev/null || echo "0")

  if [[ "$size" -le "$max_bytes" ]]; then
    return
  fi

  log "Rotating ${file} ($(( size / 1024 ))KB > $(( max_bytes / 1024 ))KB)"

  # Shift existing rotations: .3.gz -> delete, .2.gz -> .3.gz, .1 -> .2.gz, current -> .1
  local i
  for (( i = keep; i >= 2; i-- )); do
    local prev=$(( i - 1 ))
    if [[ -f "${file}.${prev}.gz" ]]; then
      mv "${file}.${prev}.gz" "${file}.${i}.gz"
    fi
  done

  # Compress .1 -> .2.gz if it exists
  if [[ -f "${file}.1" ]]; then
    gzip -f "${file}.1" 2>/dev/null && mv "${file}.1.gz" "${file}.2.gz" 2>/dev/null || true
  fi

  # Move current -> .1
  mv "$file" "${file}.1"

  # Create fresh empty file with same permissions
  touch "$file"

  log "Rotated ${file} successfully"
}

# ── 1. Rotate gateway logs and any other .log files over 5MB ─────────────────
for logfile in "${LOG_DIR}"/*.log; do
  if [[ -f "$logfile" ]]; then
    rotate_file "$logfile" "$MAX_SIZE_BYTES" "$KEEP_ROTATIONS"
  fi
done

# ── 2. Clean up /tmp/openclaw/*.log files over 1MB ──────────────────────────
for tmplog in "${TMP_DIR}"/*.log; do
  if [[ -f "$tmplog" && "$tmplog" != "$ROTATE_LOG" ]]; then
    local_size=$(stat -f%z "$tmplog" 2>/dev/null || echo "0")
    if [[ "$local_size" -gt "$TMP_MAX_SIZE_BYTES" ]]; then
      log "Truncating ${tmplog} ($(( local_size / 1024 ))KB > $(( TMP_MAX_SIZE_BYTES / 1024 ))KB)"
      # Keep the last 500 lines instead of deleting entirely
      tail -500 "$tmplog" > "${tmplog}.tmp" && mv "${tmplog}.tmp" "$tmplog"
    fi
  fi
done

# ── 3. Purge .deleted session files ──────────────────────────────────────────
DELETED_COUNT=0
for deleted_file in "${OPENCLAW_HOME}"/agents/*/sessions/*.deleted*; do
  if [[ -f "$deleted_file" ]]; then
    rm -f "$deleted_file"
    DELETED_COUNT=$(( DELETED_COUNT + 1 ))
  fi
done
if [[ "$DELETED_COUNT" -gt 0 ]]; then
  log "Purged ${DELETED_COUNT} .deleted session file(s)"
fi

log "=== Log rotation complete ==="
