# Google Workspace Integration

## When to Use
Document creation, spreadsheet management, presentation building, email access, file organization.

## Tools Available (MCP)

### Google Drive
- `createGoogleDoc`, `createGoogleSheet`, `createGoogleSlides` — create files
- `readGoogleDoc`, `getGoogleDocContent`, `getGoogleSheetContent`, `getGoogleSlidesContent` — read
- `insertText`, `updateGoogleDoc`, `updateGoogleSheet` — write
- `search`, `listFolder`, `createFolder`, `moveItem` — organize
- `uploadFile`, `downloadFile`, `shareFile` — manage

### Google Slides
- `create_presentation`, `create_slide` — build decks
- `add_multiple_text_boxes`, `update_text`, `add_image` — add content
- `format_text`, `format_shape` — style
- `add_speaker_notes`, `export_to_pdf` — finalize

### Google Sheets
- `getGoogleSheetContent`, `updateGoogleSheet`, `appendSpreadsheetRows` — data
- `formatGoogleSheetCells`, `formatGoogleSheetNumbers` — formatting
- `addDataValidation`, `addGoogleSheetConditionalFormat` — rules
- `setGoogleSheetBorders`, `mergeGoogleSheetCells` — layout

### Gmail
- `gmail_search_messages`, `gmail_read_message`, `gmail_read_thread` — read
- `gmail_create_draft` — compose (note: draft, not send)
- Accounts: jarvis@biptap.com (primary), jon@biptap.com (Jon's — draft only, never send without review)

### Google Calendar
- `gcal_create_event`, `gcal_list_events`, `gcal_get_event`, `gcal_update_event` — events
- `gcal_find_meeting_times`, `gcal_find_my_free_time` — scheduling
- See calendar-scheduling.md for Jon's specific directives

## Rules
- Jon's email (jon@biptap.com): ALWAYS draft for review, never send directly
- Jarvis email (jarvis@biptap.com): can send directly for routine operations
- File naming: descriptive, date-stamped for reports (e.g., "BSQ Weekly Report — 2026-04-03")
- All deliverables shared with jon@biptap.com

## Luna CMO Playbooks

### Content Calendar Management
Luna maintains the master content calendar in Google Sheets:
- **Sheet name:** "HoldCo Content Calendar 2026"
- **Tabs:** Jon Personal | AbsolutePay | Biptap | 1TX0 | BSQ | Video
- **Columns per tab:** Date | Platform | Type (text/video/carousel) | Hook | Status (draft/review/approved/published) | Engagement | Notes
- Use `appendSpreadsheetRows` to add planned content
- Use `updateGoogleSheet` to update status after publishing
- Weekly: pull engagement data and update the Engagement column

### Weekly CMO Report Template (Google Docs)
For Sunday BSQ Weekly Reports and monthly portfolio reviews:
1. `createGoogleDoc` with title "CMO Weekly Report — {date}"
2. Standard sections:
   - Executive Summary (3 bullets max)
   - LinkedIn Performance by Profile (table: profile, posts, engagement rate, best post)
   - Content Performance (top 3 / bottom 3 posts with engagement data)
   - Pipeline Status (BSQ leads, campaign metrics, Expandi stats)
   - Next Week Plan (3 content priorities, 3 business priorities)
3. Share with jon@biptap.com
4. Export to PDF for archival

### Campaign Brief Template (Google Docs)
When launching any new campaign:
1. `createGoogleDoc` with title "{Company} — {Campaign Name} Brief — {date}"
2. Sections: Objective | ICP | Offer | Channel Mix | Budget | KPIs | Timeline | Owners | Approval Chain
3. Share with relevant stakeholders
4. Track in ClickUp with due dates

### Performance Dashboard (Google Sheets)
Luna's weekly KPI tracking:
- **Tab 1: LinkedIn Metrics** — followers, impressions, engagement rate by profile by week
- **Tab 2: Content Performance** — post-level data (hook, engagement, format, pillar)
- **Tab 3: Campaign Pipeline** — BSQ leads, AbsolutePay waitlist, 1TX0 conversations
- **Tab 4: Video Production** — videos produced vs target per brand per week
- Use `addGoogleSheetConditionalFormat` for red/yellow/green status indicators
- Use `setGoogleSheetBorders` for clean presentation
