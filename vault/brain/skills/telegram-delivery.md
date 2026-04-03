# Telegram Delivery

## When to Use
Delivering reports, task completions, devotionals, alerts to Jon.

## Tools Required
- Telegram channel (via Openclaw gateway)
- Bot: @Holdco_apex_bot
- Jon's chat ID: `970413391`

## Message Format Rules
- **Daily reports (morning, midday, evening):** TEXT ONLY — no file attachments, everything inline
- **Task completion:** "[emoji] [task] complete — [one line summary]"
- **PDFs only for:** pitch decks, proposals, strategy docs, financial reports, legal docs, contracts
- **Weekly review:** ONE combined PDF
- **Research/general updates:** always text, never PDF
- **When in doubt:** TEXT only

## Completion Protocol (ALL AGENTS)
After EVERY completed task:
```
PING Jon on Telegram (970413391): "[emoji] [task] complete — [one line summary]"
```
NO EXCEPTIONS. Every task. Every time.

## Known Pitfalls
- No mid-task updates — only ping on 100% verified completion (COR-005)
- No status reports, no "working on it" messages
- No screenshots (COR-001)
- Delivery config in cron jobs: use `"channel": "telegram"` with `"to": "970413391"`

## Discord Logging (Zion only)
- Completed channel: 1483471553260814407
- Approvals channel: 1483471322712637622
- Bot logs: 1483471570797330432
