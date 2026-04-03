# Agent Performance Tracker

Updated by: Zion (daily), Jarvis (weekly review)
Last updated: 2026-04-03

---

## Scoring Guide

Each agent is scored weekly on 4 dimensions (1-10 each):

| Dimension | What It Measures |
|-----------|-----------------|
| **Execution** | Tasks completed on time, quality of output |
| **Reliability** | Cron jobs running, no recurring errors, consistent delivery |
| **Initiative** | Proactive flagging, self-improvement, going beyond brief |
| **Compliance** | Following rules (no screenshots, VAULT reads, completion protocol) |

**Composite Score** = average of 4 dimensions. Target: 7+ across the fleet.

---

## Weekly Scorecard Template

### Week of [DATE]

| Agent | Name | Execution | Reliability | Initiative | Compliance | Score | Notes |
|-------|------|-----------|-------------|------------|------------|-------|-------|
| orion | Jarvis | /10 | /10 | /10 | /10 | /10 | |
| apex | Nova | /10 | /10 | /10 | /10 | /10 | |
| atlas | Aria | /10 | /10 | /10 | /10 | /10 | |
| signal | Echo | /10 | /10 | /10 | /10 | /10 | |
| aurora | Luna | /10 | /10 | /10 | /10 | /10 | |
| hunter | Rex | /10 | /10 | /10 | /10 | /10 | |
| recon | Scout | /10 | /10 | /10 | /10 | /10 | |
| ledger | Vault | /10 | /10 | /10 | /10 | /10 | |
| cto | Cipher | /10 | /10 | /10 | /10 | /10 | |
| counsel | Lex | /10 | /10 | /10 | /10 | /10 | |
| pastor-zion | Zion | /10 | /10 | /10 | /10 | /10 | |
| agent-lab | Agent Lab | /10 | /10 | /10 | /10 | /10 | |

### Fleet Average: /10

---

## Tracking Rules

1. **Zion** captures daily signals: task completions, errors, feedback, cron health
2. **Jarvis** compiles the weekly scorecard every Monday as part of WEEKLY REVIEW
3. Scores below 5 on any dimension → correction memo to that agent
4. Scores below 5 for 2 consecutive weeks → escalate to Jon
5. Scores above 8 for 3 consecutive weeks → commend in weekly review
6. All scoring must be evidence-based — cite specific tasks, errors, or outputs

## Data Sources for Scoring

| Source | What It Tells You |
|--------|------------------|
| Agent CLAUDE.md mistake logs | Compliance + reliability failures |
| Cron job states (jobs.json) | Reliability — consecutiveErrors, lastRunStatus |
| ClickUp task completion | Execution — tasks done on time |
| Vault brain lessons/active.md | Initiative — lessons logged |
| Vault brain feedback/active.md | Feedback frequency and nature |
| Agent session counts | Activity level |
| Telegram delivery logs | Completion protocol compliance |

## Alerts

- Any agent with 3+ consecutive cron errors → immediate flag to Jarvis
- Any agent with 0 task completions in a week → flag to Aria
- Any agent with recurring mistake (2nd occurrence) → flag to Jon via Zion
- Fleet average below 6 → strategic review with Nova

---

## Historical Scorecards

*(Jarvis appends weekly scorecards below this line)*

---
