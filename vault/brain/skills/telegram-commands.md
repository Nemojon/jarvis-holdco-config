# Telegram Command Interface — Jon's Control Panel

Jarvis listens for these commands from Jon (Telegram ID: 970413391).

---

## Commands

| Command | Action |
|---------|--------|
| `STOP ALL` | Jarvis immediately pauses all non-essential operations. Essential crons (watchdog, oauth) continue. |
| `RESUME` | Jarvis resumes normal operations. |
| `APPROVE` (reply to approval request) | Jarvis marks the pending Tier 3 item as approved and proceeds with execution. |
| `REJECT [notes]` (reply to approval request) | Jarvis marks as rejected, sends back to owning agent with Jon's feedback for revision. |
| `STATUS` | Jarvis sends fleet status: what's running, what's pending approval, what's blocked, active goal count. |
| `PRIORITY: [text]` | Jarvis reprioritizes the fleet around Jon's stated priority. Updates GOALS.md and STATE.md. Briefs relevant agents. |
| `GOAL: [text]` | Jarvis adds a new goal to GOALS.md, assigns initial owner with Nova, and kicks off execution. |

## Tier 3 Approval Flow

When a Tier 3 decision is needed:
1. Jarvis sends Jon: "[APPROVAL NEEDED] [description] — Reply APPROVE or REJECT"
2. Jon replies with one word (APPROVE or REJECT) + optional notes
3. Jarvis acts on the decision immediately
4. If no response in 24h: Jarvis sends a reminder
5. If no response in 48h: Nova makes the call (EXCEPT budget >$1K and strategic pivots — those wait for Jon)

## Morning Brief Format (Includes Asks)

Jarvis's morning brief now includes:
- Completions since last brief
- Active goal status (from GOALS.md)
- **BLOCKERS — I need from you:** [list of specific decisions/actions only Jon can take]
- Today's priorities
- Fleet status (healthy/issues)

## Rules
- Only Jon (Telegram ID 970413391) can issue commands
- Commands are case-insensitive
- Jarvis confirms every command with a brief acknowledgment
- STOP ALL is instant — no confirmation needed
