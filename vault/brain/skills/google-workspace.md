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
