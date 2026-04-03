# Circuit Breaker — Safety Limits

Emergency controls to prevent runaway agent behavior.

---

## Automatic Triggers

| Condition | Action |
|-----------|--------|
| Any agent sends > 20 external messages in 1 hour | Auto-pause that agent, alert Jon on Telegram |
| Agent Lab applies > 3 config changes in 24 hours | Pause auto-apply, alert Nova |
| Any agent accesses a credential file outside its compartment | Alert Jon + Cipher immediately |
| Gateway error rate > 50% in 15 minutes | Alert Cipher, trigger system watchdog |
| Token spend > $50 in 1 hour | Alert Vault + Jon |

## Manual Controls

| Command | Effect |
|---------|--------|
| Jon sends `STOP ALL` on Telegram | Jarvis pauses all non-essential operations immediately |
| Jon sends `RESUME` on Telegram | Jarvis resumes normal operations |
| Cipher runs `openclaw cron disable --all` | All cron jobs paused |
| Cipher restarts gateway | Full system reset |

## Credential Compartments

| Credential File | Authorized Agents |
|----------------|-------------------|
| credentials-comms.md | Jarvis, Zion |
| credentials-research.md | Scout, Rex |
| credentials-finance.md | Vault |
| credentials-dev.md | Cipher |
| credentials-workspace.md | Aria, Jarvis |

Any agent reading a credential file outside its compartment = ALERT.

## Recovery Procedure

If STOP ALL is triggered:
1. All non-essential crons pause
2. Active agent sessions complete their current turn, then pause
3. Jarvis sends confirmation: "All operations paused. Send RESUME to restart."
4. Essential services continue: gateway, oauth-refresh, watchdog
5. Jon sends RESUME → Jarvis resumes all operations and confirms
