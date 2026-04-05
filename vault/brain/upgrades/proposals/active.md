UPGRADE PROPOSAL [2026-04-05]
What: Fix all agent cron jobs to handle CLI command changes and config validation errors (current failure: 'unknown command send', 'Config invalid ... Unrecognized key: forceIPv4')
Why: Multiple agent cron jobs have been failing due to breaking changes in the OpenClaw CLI and configuration. This disrupts all scheduled automation, reduces reliability, and increases manual overhead. Fixing this unblocks daily operations and prevents further missed or broken jobs.
Effort: QUICK WIN
Implementation notes for Cipher:
- Audit all agent-related cron scripts for use of deprecated or invalid openclaw commands (notably 'send')
- Remove or update any unrecognized/unsupported config keys (e.g. forceIPv4 in channels.telegram)
- Run `openclaw doctor --fix` to auto-heal config, then `openclaw doctor` for a clean pass
- Explicitly test/restart each cron after fix to confirm no EXIT=1 or EXIT=127 with shell errors remain
- Consider adding job exit-code monitoring to email/alert when new cron failures occur
