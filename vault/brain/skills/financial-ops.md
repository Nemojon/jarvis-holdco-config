# Financial Operations

## When to Use
Cost tracking, billing dashboard monitoring, KPI reporting, financial modeling, invoice generation.

## Tools Required
- Google Sheets MCP tools: createGoogleSheet, getGoogleSheetContent, updateGoogleSheet, appendSpreadsheetRows, formatGoogleSheetCells, formatGoogleSheetNumbers
- Google Drive MCP tools: search, createGoogleDoc, listFolder, createFolder
- ClickUp time tracking: clickup_get_task_time_entries, clickup_get_time_entries, clickup_get_bulk_tasks_time_in_status
- Browser for billing dashboards:
  - Anthropic: https://console.anthropic.com/settings/cost
  - OpenAI: https://platform.openai.com/usage
- Notion MCP tools for financial docs

## Step-by-Step: Daily Cost Report
1. Navigate to Anthropic billing dashboard via browser
2. `openclaw browser snapshot --format aria` — extract cost data as text
3. Navigate to OpenAI billing dashboard
4. Extract cost data
5. Compile daily cost summary
6. Deliver to Jarvis by 8am SGT — TEXT only

## Rules
- All numbers in USD unless specified otherwise
- Never estimate without flagging as estimate
- No rounding errors — clear variance analysis always
- Flag overspend immediately — never wait for end of month
- Never fabricate financial data
- No screenshots (COR-001)
- Daily cost report to Jarvis by 8am

## KPI Dashboard Structure
- Token usage by agent (daily/weekly/monthly)
- Cost per task/agent
- ClickUp productivity metrics (tasks completed, time in status)
- Budget vs actual variance
