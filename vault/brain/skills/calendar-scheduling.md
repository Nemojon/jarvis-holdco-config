# Calendar Scheduling

## When to Use
Creating meetings, scheduling calls, setting up events on Jon's calendar.

## Tools Required
- Google Calendar via browser (profile: `openclaw`)
- URL: https://calendar.google.com/calendar/r
- Account: jarvis@biptap.com
- MCP tools: `gcal_create_event`, `gcal_list_events`, `gcal_get_event`, `gcal_update_event`, `gcal_find_meeting_times`, `gcal_find_my_free_time`

## Jon's Locked Directive (2026-03-20 — PERMANENT)
- **ONLY** use jarvis@biptap.com Google Calendar
- Default: 1 hour duration, Google Meet link
- Add attendees: jon@biptap.com + client/partner email
- Send invite immediately — no secondary approval needed
- **NO clarifying questions** if info was already given
- **NO .ics files, NO email workarounds** — browser/API only (LES-001)

## Step-by-Step
1. Check Jon's availability: `gcal_find_my_free_time` or `gcal_list_events`
2. Create event: `gcal_create_event` with title, time, duration (1hr default), Google Meet, attendees
3. Send invite immediately
4. Confirm to Jarvis/Jon: "[time] meeting with [person] — invite sent"

## Known Pitfalls
- Jon explicitly rejected .ics file approach multiple times (LES-001) — NEVER use
- Chrome must be running for browser-based calendar operations — use MCP tools as fallback (LES-007)
- Always check for conflicts before scheduling
