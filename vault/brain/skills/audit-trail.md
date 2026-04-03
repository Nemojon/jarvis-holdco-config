# Audit Trail — External Action Logging

All agents: log every external action you take.

---

## What to Log

Any action that reaches outside the Openclaw system:
- Telegram messages sent (to Jon, Discord, etc.)
- Web browsing for research (URL visited)
- API calls to external services (Apify, ClickUp, etc.)
- Content published or scheduled
- Outreach emails or messages sent
- Calendar modifications
- File uploads or downloads to external services

## Log Format

Append to: `vault/brain/logs/external-actions-{YYYY-MM-DD}.md`

```
[HH:MM] [AGENT_ID] [ACTION] [TARGET] [STATUS]
```

Examples:
```
[07:30] orion TELEGRAM_SEND 970413391 OK — Morning command delivered
[08:15] recon WEB_FETCH finextra.com OK — Morning intel scan
[09:00] hunter APIFY_RUN linkedin-profile-posts OK — Prospect research
[10:30] signal CONTENT_DRAFT linkedin/jon OK — 3 drafts written to workspace
```

## Audit Summary

Jarvis includes a brief audit summary in the evening digest:
- Total external actions today: [N]
- By agent: [breakdown]
- Anomalies: [any unusual patterns]

## Retention
- Keep daily logs for 30 days
- Archive older logs to vault/brain/logs/archive/
