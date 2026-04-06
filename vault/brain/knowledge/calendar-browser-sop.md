# Calendar & Browser SOP — Permanent

## Calendar Access
- **Tool:** Google Calendar MCP (gcal_list_events, gcal_create_event, etc.)
- **Account:** jon@biptap.com (primary, owner)
- **DO NOT** use the browser to check calendar — use the MCP tools directly
- **DO NOT** navigate to calendar.google.com for verification — use gcal_list_events

## Browser Profiles
| Profile | Driver | Use For |
|---------|--------|---------|
| `user` (default) | existing-session on :9222 | Real Brave — web research, LinkedIn, signed-in sessions |
| `brave` | existing-session on :9222 | Alias for user |
| `openclaw` | openclaw on :9223 | Isolated browser — safe for untrusted sites |

## Browser Account
- Real Brave profile has `jonathan.lyt89ai@gmail.com` signed in (agent/AI account)
- Jon's real accounts (jon@biptap.com) are accessed via MCP tools, not browser

## If Browser Breaks
1. Run: `bash ~/.openclaw/scripts/brave-with-debug.sh`
2. Check: `lsof -i :9222` — should show Brave listening
3. Check: `openclaw browser status` — should show `profile: user, running: true`
