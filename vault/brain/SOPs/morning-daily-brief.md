# SOP: Morning Daily Brief
**Created:** 2026-04-04
**Owner:** Jarvis (orion)
**Frequency:** Daily at 7:30 AM SGT
**Cron ID:** 41e5328f-9277-484d-80ff-f22a26bb8023

## Purpose
Deliver Jon a single consolidated morning message with his calendar, emails, tasks, and intel — everything he needs to plan his day.

## Data Sources & Methods (EXACT — do not deviate)

### 1. Calendar (jon@biptap.com)
- **Method:** Browser (Brave CDP on port 9222)
- **URL:** `https://calendar.google.com/calendar/b/1/r/day` (account /u/1 = jon@biptap.com)
- **NOT** gog CLI (calendar scope missing, only gmail scope)
- Snapshot the page, extract all events for today
- Include: time, title, location, attendees if visible

### 2. Emails (jon@biptap.com + jonathan.lyt89@gmail.com)
- **Method:** gog CLI
- **Commands:**
  - `gog gmail search 'is:unread newer_than:24h' --max 20 --account jon@biptap.com --json`
  - `gog gmail search 'is:unread newer_than:24h' --max 20 --account jonathan.lyt89@gmail.com --json`
- **Highlight:** Emails from team (Jarrett, Anna, Blanche, Gene, Berlin, Jay, Bogdan, Aditya, any @biptap.com)
- **Highlight:** Emails from clients, investors, partners
- **Skip:** Newsletters, promos, automated alerts (unless critical)

### 3. ClickUp Tasks
- **Method:** API
- **Endpoint:** `https://api.clickup.com/api/v2/team/90181643979/task?assignees[]=101431798&order_by=due_date&reverse=false&include_closed=false`
- **Header:** `Authorization: pk_101431798_V75BT36AI2754IV3RJVACB0W3MGMMAZH`
- Show overdue + due today + urgent items

### 4. Weather
- **Method:** `curl wttr.in/Singapore?format=%C+%t+%h+%w`

### 5. Morning Intel (Scout)
- **File:** `/Users/apex/.openclaw/workspace-orion/memory/morning-intel-YYYY-MM-DD.md`
- Top 3 items only

### 6. BSQ Daily (Luna)
- **File:** `/Users/apex/.openclaw/workspace-orion/memory/bsq-daily-YYYY-MM-DD.md`

### 7. Content Drafts (Echo)
- **File:** `/Users/apex/.openclaw/workspace-orion/memory/content-drafts-YYYY-MM-DD.md`
- Show hooks only (1 line per draft)

### 8. Overnight R&D
- **File:** `/Users/apex/.openclaw/logs/agent-lab-nightly.log` (last 50 lines)
- **File:** `/Users/apex/.openclaw/vault/brain/upgrades/proposals/active.md`
- **File:** `/Users/apex/.openclaw/vault/brain/upgrades/changelog.md`

## Pre-requisites (MUST verify before morning cron runs)
1. Brave Browser running with `--remote-debugging-port=9222`
2. gog auth active for both gmail accounts
3. ClickUp API key valid

## Output Format
ONE Telegram text message to Jon (970413391). NO file attachments.

```
✝️ DEVOTIONAL
[2-3 lines scripture/wisdom]

🌤 WEATHER — Singapore
[conditions, temp, humidity]

📅 TODAY'S SCHEDULE
[time — event — location] for each event
[or "No events today"]

📧 IMPORTANT EMAILS (unread)
[🔴 sender — subject — 1-line summary] for important
[total X unread, Y highlighted]

📋 CLICKUP — Open Tasks
[priority] task name — due date
[overdue items flagged]

📰 INTEL TOP 3
[from Scout's morning-intel file]

📊 BSQ PULSE
[from Luna's bsq-daily file]

✍️ CONTENT HOOKS
[1 line per draft from Echo]

🧪 OVERNIGHT R&D
[Agent Lab findings, Cipher upgrades, pending proposals]

🤖 FLEET STATUS
[healthy/errored cron count]

🎯 #1 PRIORITY
[single most important thing for Jon today]
```

## Failure Handling
- If browser down → state "Calendar: browser offline" and continue
- If gog fails → state "Email check failed" and continue
- If ClickUp fails → state "ClickUp: API error" and continue
- NEVER skip the entire brief because one source fails
- ALWAYS deliver something

## Notes
- jon@biptap.com is browser account /u/1 (NOT /u/0 which is jonathan.lyt89ai@gmail.com)
- jarvis@biptap.com was the old calendar account — deprecated for this purpose
- Browser must be restarted with CDP flag if Mac Mini reboots
