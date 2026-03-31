# UPGRADE PROPOSALS

Nexus writes proposals here. Jon approves/rejects.
Status: PROPOSED → APPROVED → IMPLEMENTING → DEPLOYED → VERIFIED

---

## UPGRADE PROPOSAL 2026-03-31

**What:** Fix cascading cron job failures — `openclaw send` command removed/renamed

**Why:** 9 cron jobs (recon, apex, orion, nova-ap, nova-bt, nova-1x, nova-bsq, hunter, ledger) are ALL failing with `error: unknown command 'send'`. This means the entire fleet's scheduled tasks have been broken since ~March 29. The `dead-letter.sh` wrapper is catching them, but no actual work is being done. Secondary issue: config has unrecognized `forceIPv4` key in telegram channel config causing test-cron to fail too.

**Effort:** QUICK WIN

**Implementation notes for Cipher:**
1. Check what `openclaw send` was replaced with in 2026.3.28 — likely `openclaw message send` or similar. Run `openclaw help` to find the new command.
2. Update all crontab entries or the scripts they call to use the new command syntax.
3. Remove `forceIPv4` from `~/.openclaw/openclaw.json` → `channels.telegram` (or run `openclaw doctor --fix`).
4. After fixing, manually trigger one job to verify the pipeline is restored.
5. Bonus: 10/11 agents are bloat-flagged (10-11 items each, threshold 5). Consider a workspace cleanup pass while touching agent configs.

**Impact:** HIGH — fleet is effectively running blind on scheduled tasks. Every agent with a cron job is affected.

**Status:** PROPOSED
