# Fireflies Auto-Summary SOP

## Overview
Automated system that checks Fireflies.ai for new meeting transcripts every 30 minutes and posts formatted summaries to:
- **Telegram:** Jon (@nemojon, ID: 970413391)

## Architecture
```
[Fireflies.ai] → [OpenClaw Cron (every 30m)] → [Cipher Agent]
                                                    ↓
                                              Fetch new transcripts via GraphQL API
                                                    ↓
                                              Generate formatted summary
                                                    ↓
                                              [Telegram]
                                              (message tool)
```

## Components

### 1. Fireflies API
- **Endpoint:** `https://api.fireflies.ai/graphql`
- **API Key:** `60b7c053-ddf9-4a5d-858a-914f7b4e47f5` (jon@biptap.com, PRO account)
- **Queries used:**
  - `transcripts` - List all transcripts with dates
  - `transcript(id)` - Get full details including summary, action items, overview

### 2. Shell Script
- **Location:** `/Users/apex/.openclaw/workspace-cto/scripts/fireflies-meeting-summary.sh`
- **State file:** `/Users/apex/.openclaw/workspace-cto/scripts/.fireflies-last-check` (timestamp in ms)
- **Log file:** `/Users/apex/.openclaw/workspace-cto/scripts/fireflies-summary.log`
- **What it does:**
  1. Reads last check timestamp
  2. Fetches all transcripts from Fireflies
  3. Filters for new ones since last check
  4. For each new meeting: fetches summary, formats it
  5. Outputs formatted summaries for Telegram posting
  6. Saves new checkpoint

### 3. OpenClaw Cron Job
- **Name:** `fireflies-meeting-summary`
- **ID:** `b432369d-b734-4d98-acfa-b53821727b2c`
- **Schedule:** Every 30 minutes
- **Agent:** Cipher (CTO)
- **Session:** Isolated (doesn't pollute main session)
- **Delivery:** Announces to Telegram 970413391

## Summary Format
```
📞 MEETING SUMMARY — [Meeting Title]
📅 [Date] | ⏱ [Duration] | 👥 [Participants]

🎯 KEY DECISIONS:
• [decision 1]
• [decision 2]

✅ ACTION ITEMS:
• [Action] → [Owner] → [Deadline]

💡 KEY INSIGHTS:
• [insight 1]

📋 NEXT STEPS:
• [next step 1]
```

## Plaud Integration
Plaud recordings that are uploaded to Fireflies will be automatically captured by this same system. To manually upload Plaud recordings:
1. Export from Plaud app as audio file
2. Upload to Fireflies at https://app.fireflies.ai/upload
3. System will detect and summarize within 30 minutes

## Management Commands
```bash
# Check cron status
openclaw cron list

# Disable temporarily
openclaw cron disable fireflies-meeting-summary

# Re-enable
openclaw cron enable fireflies-meeting-summary

# Manual run
openclaw cron run fireflies-meeting-summary

# View run history
openclaw cron runs fireflies-meeting-summary

# Check logs
tail -50 /Users/apex/.openclaw/workspace-cto/scripts/fireflies-summary.log
```

## Setup Date
- **Created:** March 19, 2026
- **First test run:** ✅ Success — 2 meetings processed and posted to Telegram
  - "Call with Devin" (58m)
  - "Jarrett <> Berlin" (32m)
