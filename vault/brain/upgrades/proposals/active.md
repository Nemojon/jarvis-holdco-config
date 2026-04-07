UPGRADE PROPOSAL 2026-04-07
- What: Harden cron/dead-letter execution by making cron jobs invoke the OpenClaw CLI via an absolute path or validated shell wrapper, and replace legacy `send` calls with the supported messaging API.
- Why: The failures log shows repeated cron exits from `openclaw: command not found` and `unknown command 'send'`, which means scheduled jobs are brittle and can miss alerts/tasks.
- Effort: QUICK WIN
- Implementation notes for Cipher: update `/Users/apex/.openclaw/scripts/dead-letter.sh` and the cron templates to use a resolvable OpenClaw binary path (or `npx openclaw`/full Homebrew path), add a startup sanity check for `openclaw --help`, and sweep any scripts still calling deprecated `send` so they use the current channel/message tool path.
