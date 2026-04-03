# ClickUp Task Management

## When to Use
Task creation, pipeline tracking, status updates, team accountability, overdue flagging.

## Tools Required
- ClickUp API (REST)
- Workspace: Biptap (Team ID: `90181643979`)
- API Key: `pk_101431798_V75BT36AI2754IV3RJVACB0W3MGMMAZH`
- Jon's user ID: `101431798`
- MCP tools: `clickup_filter_tasks`, `clickup_create_task`, `clickup_update_task`, `clickup_get_task`, `clickup_get_task_comments`, `clickup_create_task_comment`, `clickup_get_workspace_hierarchy`

## Common Operations

### List tasks by assignee
```
GET https://api.clickup.com/api/v2/team/90181643979/task?assignees[]=101431798&order_by=due_date
Headers: Authorization: pk_101431798_V75BT36AI2754IV3RJVACB0W3MGMMAZH
```

### Create task
```
POST https://api.clickup.com/api/v2/list/{list_id}/task
Body: { "name": "...", "assignees": [101431798], "due_date": ..., "priority": 1-4 }
```

### Update task status
```
PUT https://api.clickup.com/api/v2/task/{task_id}
Body: { "status": "in progress" }
```

## Known Pitfalls
- **Deduplicate by task ID** before presenting to Jon — same task can appear in multiple status columns (LES-006)
- All new leads MUST have due dates + owners assigned (Jarvis lesson)
- Flag stale/overdue items immediately — don't let them accumulate
- Time tracking: use `clickup_get_task_time_entries` for productivity KPIs

## Rules
- Every task needs: owner, due date, priority
- Route tasks within 60 seconds (Aria rule)
- Check for duplicates before creating
- Never create tasks without proper context from Jon or Jarvis
