#!/bin/bash
# GitHub Config Backup — pushes openclaw config to private GitHub repo
# Runs daily at 2am SGT via launchd
# Remote URL (with PAT) is stored in git config, not in this script.
set -euo pipefail

LOGFILE="/tmp/openclaw/github-backup.log"
OPENCLAW_DIR="/Users/apex/.openclaw"

mkdir -p /tmp/openclaw

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "=== GitHub backup started ==="

cd "$OPENCLAW_DIR"

# Ensure git repo exists
if [ ! -d ".git" ] || ! git rev-parse --git-dir > /dev/null 2>&1; then
  log "ERROR: No git repo found in $OPENCLAW_DIR"
  exit 1
fi

# Use git add (without -f) so .gitignore is respected for bulk adds.
# Only use -f for specific known-safe files.

# Core config files (known safe, force-add)
git add -f .gitignore 2>/dev/null || true
git add -f openclaw.json 2>/dev/null || true
git add -f exec-approvals.json 2>/dev/null || true
git add -f feature-flags.json 2>/dev/null || true

# Agent definitions — only .md files (soul, identity, CLAUDE, BOOTSTRAP)
for agent_dir in agents/*/; do
  [ -d "$agent_dir" ] || continue
  find "$agent_dir" -maxdepth 3 -name "*.md" \
    -exec git add -f {} \; 2>/dev/null || true
done

# Workspace configs — only .md and .json (gitignore handles exclusions)
for ws_dir in workspace-*/; do
  [ -d "$ws_dir" ] || continue
  find "$ws_dir" -maxdepth 2 -name "*.md" -exec git add -f {} \; 2>/dev/null || true
  find "$ws_dir" -maxdepth 2 -name "*.json" \
    ! -name "auth-profiles.json" \
    -exec git add -f {} \; 2>/dev/null || true
done

# Cron — only the main jobs.json, skip backups and run logs
# Skip if it contains embedded secrets (API tokens in cron payloads)
if [ -f "cron/jobs.json" ]; then
  if grep -qiE "(ghp_[a-zA-Z0-9]{20,}|apify_api_|ntn_[a-zA-Z0-9]|sk-[a-zA-Z0-9]{20,}|xoxb-)" "cron/jobs.json" 2>/dev/null; then
    log "SKIP cron/jobs.json (contains embedded secrets in payloads)"
  else
    git add -f cron/jobs.json 2>/dev/null || true
  fi
fi

# Vault — only .md and .json files, skip credentials and files with embedded secrets
if [ -d "vault/" ]; then
  find vault/ \( -name "*.md" -o -name "*.json" \) \
    ! -path "*/CREDENTIALS*" ! -path "*/credentials/*" ! -name "*credential*" \
    -print0 | while IFS= read -r -d '' f; do
    if grep -qiE "(ghp_[a-zA-Z0-9]{20,}|apify_api_|ntn_[a-zA-Z0-9]|sk-[a-zA-Z0-9]{20,}|xoxb-)" "$f" 2>/dev/null; then
      log "SKIP vault (contains secret): $f"
    else
      git add -f "$f" 2>/dev/null || true
    fi
  done
fi

# Scripts — add individually, skip files containing hardcoded secrets
[ -d "scripts/" ] && find scripts/ -type f \( -name "*.sh" -o -name "*.js" \) | while read f; do
  # Skip files that contain API keys/tokens/secrets inline
  if grep -qiE "(ghp_|sk-|apify_|APIFY_TOKEN|ntn_|secret_|xoxb-|xoxp-)" "$f" 2>/dev/null; then
    log "SKIP (contains secret): $f"
    continue
  fi
  git add -f "$f" 2>/dev/null || true
done

# Identity configs — .md and .json only
[ -d "identity/" ] && find identity/ -name "*.md" -o -name "*.json" | while read f; do
  git add -f "$f" 2>/dev/null || true
done

# Memory — only .md files, never .sqlite
[ -d "memory/" ] && find memory/ -name "*.md" -exec git add -f {} \; 2>/dev/null || true

# Final safety net: unstage anything that looks like a secret
STAGED_SECRETS=$(git diff --cached --name-only | grep -iE "(auth-profiles|\.env|credentials|\.key|\.pem|\.sqlite|\.db|\.bak)" || true)
if [ -n "$STAGED_SECRETS" ]; then
  log "WARNING: Unstaging potential secret files: $STAGED_SECRETS"
  echo "$STAGED_SECRETS" | xargs -I{} git reset HEAD -- "{}" 2>/dev/null || true
fi

# Double-check: scan staged file contents for token patterns
for staged_file in $(git diff --cached --name-only 2>/dev/null); do
  [ -f "$staged_file" ] || continue
  if grep -qiE "(ghp_[a-zA-Z0-9]{36}|sk-[a-zA-Z0-9]{20,}|apify_api_[a-zA-Z0-9]+)" "$staged_file" 2>/dev/null; then
    log "WARNING: Unstaging file with embedded token: $staged_file"
    git reset HEAD -- "$staged_file" 2>/dev/null || true
  fi
done

# Commit and push if there are changes
CHANGES=$(git diff --cached --name-only | wc -l | tr -d ' ')
if [ "$CHANGES" -gt 0 ]; then
  git commit -m "Backup $(date '+%Y-%m-%d %H:%M') — $CHANGES files"
  git push origin main 2>&1 | tee -a "$LOGFILE"
  log "Pushed $CHANGES file(s) to GitHub"
else
  log "No changes to push"
fi

log "=== GitHub backup completed ==="
