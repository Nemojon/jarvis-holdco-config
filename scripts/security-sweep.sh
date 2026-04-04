#!/bin/bash
# security-sweep.sh — Nightly security audit for Cortex (Mac mini) + Openclaw
# Runs daily at 23:00 SGT. Alerts Jon via Telegram on critical/high findings.
# Created: 2026-04-04
#
# Checks:
#   - New/modified LaunchAgents & LaunchDaemons (backdoor detection)
#   - Prompt injection patterns in agent workspaces
#   - Embedded secrets/PATs in git remotes
#   - File permission regressions (world-readable .env, creds, keys)
#   - Unauthorized open ports on all interfaces
#   - New user accounts or sudoers changes
#   - SUID/SGID binaries in home directory
#   - Suspicious processes (reverse shells, crypto miners, etc.)
#   - Suspicious network connections (unexpected outbound)
#   - Crontab tampering
#   - FileVault & SIP status
#   - Malicious files (web shells, known bad patterns)
#   - Openclaw config integrity (unexpected changes)

set -uo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
OPENCLAW_DIR="$HOME/.openclaw"
LOG_DIR="$OPENCLAW_DIR/logs"
LOG="$LOG_DIR/security-sweep.log"
BASELINE_DIR="$LOG_DIR/security-baselines"
BOT_TOKEN=$(python3 -c "import json; print(json.load(open('$OPENCLAW_DIR/openclaw.json'))['channels']['telegram']['botToken'])" 2>/dev/null)
CHAT_ID="970413391"

mkdir -p "$LOG_DIR" "$BASELINE_DIR"

ts=$(date '+%Y-%m-%d %H:%M:%S SGT')
findings=""
critical_count=0
high_count=0
medium_count=0

log() { echo "[$ts] $1" >> "$LOG"; }
finding() {
  local severity="$1" detail="$2"
  findings="${findings}\n[${severity}] ${detail}"
  case "$severity" in
    CRITICAL) critical_count=$((critical_count+1)) ;;
    HIGH)     high_count=$((high_count+1)) ;;
    MEDIUM)   medium_count=$((medium_count+1)) ;;
  esac
  log "$severity: $detail"
}

log "═══ Security sweep started ═══"

# ─── 1. LaunchAgent / LaunchDaemon Changes (Backdoor Detection) ───────────
log "Checking LaunchAgents/Daemons..."
current_agents=$(ls -1 ~/Library/LaunchAgents/ /Library/LaunchAgents/ /Library/LaunchDaemons/ 2>/dev/null | sort)
baseline_file="$BASELINE_DIR/launch-agents.baseline"

if [ -f "$baseline_file" ]; then
  diff_result=$(diff <(cat "$baseline_file") <(echo "$current_agents") 2>/dev/null)
  if [ -n "$diff_result" ]; then
    new_agents=$(echo "$diff_result" | grep '^>' | sed 's/^> //')
    removed_agents=$(echo "$diff_result" | grep '^<' | sed 's/^< //')
    [ -n "$new_agents" ] && finding "CRITICAL" "New LaunchAgent/Daemon detected: $new_agents"
    [ -n "$removed_agents" ] && finding "MEDIUM" "LaunchAgent/Daemon removed: $removed_agents"
  fi
fi
echo "$current_agents" > "$baseline_file"

# ─── 2. Prompt Injection Scan (Agent Workspaces) ──────────────────────────
log "Scanning for prompt injection patterns..."
injection_patterns='(ignore previous|disregard all|system prompt|you are now|jailbreak|DAN mode|bypass safety|ignore instructions|override system|pretend you are|act as if you have no restrictions|<\|im_start\|>|<\|endoftext\|>|\[INST\]|<<SYS>>)'

for ws in "$OPENCLAW_DIR"/workspace-*/; do
  agent_name=$(basename "$ws")
  hits=$(grep -rlE "$injection_patterns" "$ws" \
    --include="*.md" --include="*.txt" --include="*.json" --include="*.js" --include="*.py" \
    --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null | head -5)
  if [ -n "$hits" ]; then
    finding "CRITICAL" "Prompt injection pattern in $agent_name: $(echo $hits | tr '\n' ', ')"
  fi
done

# Also scan incoming messages/memory for injection
for mem_dir in "$OPENCLAW_DIR"/memory "$OPENCLAW_DIR"/workspace-*/memory; do
  if [ -d "$mem_dir" ]; then
    hits=$(grep -rlE "$injection_patterns" "$mem_dir" --include="*.md" --include="*.json" 2>/dev/null | head -3)
    [ -n "$hits" ] && finding "HIGH" "Injection pattern in memory: $(echo $hits | tr '\n' ', ')"
  fi
done

# ─── 3. Git Remote PAT/Secret Leaks ──────────────────────────────────────
log "Checking git remotes for embedded credentials..."
for d in "$OPENCLAW_DIR" "$OPENCLAW_DIR"/workspace-*; do
  if [ -d "$d/.git" ]; then
    url=$(cd "$d" && git remote get-url origin 2>/dev/null)
    if echo "$url" | grep -qiE '(ghp_|gho_|github_pat_|token|password|secret)'; then
      finding "CRITICAL" "Embedded credential in git remote: $(basename $d)"
    fi
  fi
done

# ─── 4. File Permission Regressions ──────────────────────────────────────
log "Checking sensitive file permissions..."

# .env files
while IFS= read -r f; do
  perms=$(stat -f '%Lp' "$f" 2>/dev/null)
  if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
    finding "HIGH" ".env file too permissive ($perms): $f"
  fi
done < <(find /Users/apex -maxdepth 4 \( -name ".env" -o -name ".env.*" \) ! -name "*.example" ! -name "*.tpl" 2>/dev/null | grep -v node_modules | grep -v '.vscode')

# WhatsApp / credential files
exposed_creds=$(find "$OPENCLAW_DIR/credentials" -type f -perm -o+r 2>/dev/null | wc -l | tr -d ' ')
if [ "$exposed_creds" -gt 0 ]; then
  finding "HIGH" "$exposed_creds credential files are world-readable"
fi

# Key config files
for f in "$OPENCLAW_DIR/openclaw.json" "$OPENCLAW_DIR/cron/jobs.json" "$OPENCLAW_DIR/exec-approvals.json"; do
  if [ -f "$f" ]; then
    perms=$(stat -f '%Lp' "$f" 2>/dev/null)
    if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
      finding "HIGH" "Config too permissive ($perms): $(basename $f)"
    fi
  fi
done

# Workspace directory permissions
for d in "$OPENCLAW_DIR"/workspace-*; do
  perms=$(stat -f '%Lp' "$d" 2>/dev/null)
  if [ "$perms" != "700" ] && [ "$perms" != "750" ]; then
    finding "MEDIUM" "Workspace dir permissive ($perms): $(basename $d)"
  fi
done

# ─── 5. Unauthorized Open Ports ──────────────────────────────────────────
log "Checking open ports..."
# Ports on all interfaces (not localhost) excluding known-safe (rapportd, tailscale)
unsafe_ports=$(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null \
  | grep '\*:' \
  | grep -v rapportd \
  | grep -v tailscale \
  | awk '{print $1 ":" $9}')
if [ -n "$unsafe_ports" ]; then
  finding "HIGH" "Ports listening on all interfaces: $unsafe_ports"
fi

# ─── 6. User Account Changes ─────────────────────────────────────────────
log "Checking user accounts..."
current_users=$(dscl . -list /Users UserShell 2>/dev/null | grep -v '/usr/bin/false' | grep -v '/bin/false' | grep -v '_' | sort)
baseline_users="$BASELINE_DIR/users.baseline"
if [ -f "$baseline_users" ]; then
  new_users=$(diff <(cat "$baseline_users") <(echo "$current_users") | grep '^>' | sed 's/^> //')
  [ -n "$new_users" ] && finding "CRITICAL" "New user account with shell: $new_users"
fi
echo "$current_users" > "$baseline_users"

# Admin group
admin_members=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/GroupMembership: //')
baseline_admins="$BASELINE_DIR/admins.baseline"
if [ -f "$baseline_admins" ]; then
  old_admins=$(cat "$baseline_admins")
  if [ "$admin_members" != "$old_admins" ]; then
    finding "CRITICAL" "Admin group membership changed: was [$old_admins] now [$admin_members]"
  fi
fi
echo "$admin_members" > "$baseline_admins"

# ─── 7. SUID/SGID Binaries ───────────────────────────────────────────────
log "Checking for SUID/SGID binaries in home..."
suid_files=$(find /Users/apex -perm -4000 -o -perm -2000 2>/dev/null | head -5)
[ -n "$suid_files" ] && finding "CRITICAL" "SUID/SGID binary in home dir: $suid_files"

# ─── 8. Suspicious Processes ─────────────────────────────────────────────
log "Checking for suspicious processes..."
# Reverse shells, crypto miners, known malware patterns
suspicious=$(ps aux 2>/dev/null | grep -iE '(nc -l|ncat -l|/bin/sh -i|bash -i|python.*pty.spawn|xmrig|minerd|cryptonight|coinminer|reverse_shell|meterpreter|cobalt.*strike|beacon\.dll)' | grep -v grep)
[ -n "$suspicious" ] && finding "CRITICAL" "Suspicious process detected: $(echo "$suspicious" | head -3)"

# Unexpected outbound connections to known-bad ports
bad_conns=$(lsof -iTCP -sTCP:ESTABLISHED -P -n 2>/dev/null | awk '{print $1, $9}' | grep -E ':(4444|5555|6666|1337|31337|9001|8443|2222)\b' | head -5)
[ -n "$bad_conns" ] && finding "CRITICAL" "Suspicious outbound connection: $bad_conns"

# ─── 9. Crontab Integrity ────────────────────────────────────────────────
log "Checking crontab integrity..."
current_crontab=$(crontab -l 2>/dev/null | md5 2>/dev/null)
baseline_crontab="$BASELINE_DIR/crontab.md5"
if [ -f "$baseline_crontab" ]; then
  old_md5=$(cat "$baseline_crontab")
  if [ "$current_crontab" != "$old_md5" ]; then
    finding "HIGH" "Crontab has been modified since last sweep"
  fi
fi
echo "$current_crontab" > "$baseline_crontab"

# ─── 10. System Security Features ────────────────────────────────────────
log "Checking system security posture..."
sip_status=$(csrutil status 2>&1)
echo "$sip_status" | grep -q "enabled" || finding "CRITICAL" "SIP is DISABLED"

gatekeeper=$(spctl --status 2>&1)
echo "$gatekeeper" | grep -q "enabled" || finding "CRITICAL" "Gatekeeper is DISABLED"

filevault=$(fdesetup status 2>&1)
echo "$filevault" | grep -q "On" || finding "MEDIUM" "FileVault is OFF — disk not encrypted"

# ─── 11. Malicious File Scan ─────────────────────────────────────────────
log "Scanning for malicious files..."
# Web shells, reverse shells, suspicious scripts
malicious_patterns='(eval\s*\(\s*base64_decode|system\s*\(\s*\$_|exec\s*\(\s*\$_|passthru\s*\(|shell_exec\s*\(|<?php.*eval|nc\s+-e|bash\s+-c.*>/dev/tcp|import\s+pty;.*spawn|socket\.socket.*connect)'

mal_hits=$(grep -rlE "$malicious_patterns" \
  "$OPENCLAW_DIR/scripts/" \
  "$OPENCLAW_DIR/workspace-"*/  \
  --include="*.sh" --include="*.py" --include="*.js" --include="*.php" \
  --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null \
  | grep -v 'security-sweep.sh' | head -5)
[ -n "$mal_hits" ] && finding "CRITICAL" "Possible malicious code: $(echo $mal_hits | tr '\n' ', ')"

# Unexpected executable files in workspace roots
for ws in "$OPENCLAW_DIR"/workspace-*/; do
  new_execs=$(find "$ws" -maxdepth 1 -type f -perm +111 ! -name "*.md" ! -name "*.json" 2>/dev/null | head -3)
  [ -n "$new_execs" ] && finding "MEDIUM" "Unexpected executable in $(basename $ws): $new_execs"
done

# ─── 12. Openclaw Config Integrity ───────────────────────────────────────
log "Checking config integrity..."
config_md5=$(md5 -q "$OPENCLAW_DIR/openclaw.json" 2>/dev/null)
baseline_config="$BASELINE_DIR/config.md5"
if [ -f "$baseline_config" ]; then
  old_config_md5=$(cat "$baseline_config")
  if [ "$config_md5" != "$old_config_md5" ]; then
    # Check what changed — is it just normal operation or suspicious?
    finding "MEDIUM" "openclaw.json modified since last sweep (may be normal config update)"
  fi
fi
echo "$config_md5" > "$baseline_config"

# ─── 13. Unauthorized SSH Keys ───────────────────────────────────────────
log "Checking SSH authorized keys..."
if [ -f "$HOME/.ssh/authorized_keys" ]; then
  key_count=$(wc -l < "$HOME/.ssh/authorized_keys" | tr -d ' ')
  baseline_keys="$BASELINE_DIR/ssh-keys.count"
  if [ -f "$baseline_keys" ]; then
    old_count=$(cat "$baseline_keys")
    if [ "$key_count" != "$old_count" ]; then
      finding "CRITICAL" "SSH authorized_keys changed: was $old_count keys, now $key_count"
    fi
  fi
  echo "$key_count" > "$baseline_keys"
fi

# New authorized_keys file appearing
if [ -f "$HOME/.ssh/authorized_keys" ]; then
  baseline_exists="$BASELINE_DIR/ssh-keys.exists"
  if [ ! -f "$baseline_exists" ]; then
    finding "HIGH" "SSH authorized_keys file exists — verify this is intentional"
  fi
  echo "1" > "$baseline_exists"
fi

# ─── 14. World-Writable Directories ──────────────────────────────────────
log "Checking world-writable dirs..."
ww_dirs=$(find "$OPENCLAW_DIR" -type d -perm -o+w 2>/dev/null)
[ -n "$ww_dirs" ] && finding "HIGH" "World-writable directory in Openclaw: $ww_dirs"

# ─── 15. Tmp Directory Scan ──────────────────────────────────────────────
log "Checking /tmp for suspicious openclaw files..."
sus_tmp=$(find /tmp/openclaw -name "*.sh" -o -name "*.py" -o -name "*.php" 2>/dev/null | head -5)
[ -n "$sus_tmp" ] && finding "MEDIUM" "Executable scripts in /tmp/openclaw: $sus_tmp"

# ─── Report & Alert ──────────────────────────────────────────────────────
total=$((critical_count + high_count + medium_count))
log "Sweep complete: $critical_count critical, $high_count high, $medium_count medium"

if [ "$total" -eq 0 ]; then
  log "All clear — no security issues found"
  summary="✅ *Cortex Security Sweep — All Clear*

$(date '+%Y-%m-%d %H:%M SGT')

No security issues found.
• LaunchAgents: unchanged
• Prompts: clean
• Creds: locked
• Ports: secure
• Processes: normal
• System: SIP ✓ Gatekeeper ✓"

  # Send all-clear to Telegram (brief)
  if [ -n "$BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo "$summary" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"), \"parse_mode\": \"Markdown\"}" \
      > /dev/null 2>&1
  fi
else
  # Build alert message
  alert="🚨 *Cortex Security Sweep — $total Issues Found*

$(date '+%Y-%m-%d %H:%M SGT')

*$critical_count critical | $high_count high | $medium_count medium*
$(echo -e "$findings")

_Full log: ~/.openclaw/logs/security-sweep.log_"

  # Always send if there are findings
  if [ -n "$BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo "$alert" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"), \"parse_mode\": \"Markdown\"}" \
      > /dev/null 2>&1
    log "Alert sent to Telegram ($total issues)"
  fi
fi

log "═══ Security sweep complete ═══"
