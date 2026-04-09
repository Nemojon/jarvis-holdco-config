## MANDATORY COMPLETION CHECK
Before responding HEARTBEAT_OK, verify:
1. Did you complete any tasks since last heartbeat?
2. If yes: did you write results to your workspace memory file?
3. If yes: did you write learnings to your MEMORY.md?
4. If any of these are NO — do them now before responding.

## FLEET COMPLETION AUDIT
Check each sub-agent's latest workspace memory file date:
- ls -lt ~/.openclaw/workspace-*/memory/ | head -20
- If any agent's last memory file is >48h old: flag as SILENT
- Write silent agents to STATE.md under a "FLEET HEALTH" section
