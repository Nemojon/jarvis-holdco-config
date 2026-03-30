# HoldCo Agent Architecture
Version: 1.0 | Date: 2026-02-27

## Agent Fleet (11 Active)
| Agent | ID | Role | Model | Layer |
|-------|----|------|-------|-------|
| Jarvis | orion | COO / Command | claude-opus-4-5 | Command |
| Nova | apex | Co-CEO / Strategy | claude-opus-4-5 | Command |
| Cipher | cto | CTO / Architecture | claude-opus-4-5 | Command |
| Luna | aurora | Marketing & Growth | gpt-4.1 | Function |
| Echo | signal | Content & Comms | gpt-4.1 | Function |
| Rex | hunter | Pipeline & BD | gpt-4.1 | Function |
| Aria | atlas | Chief of Staff | gpt-4.1-mini | Ops |
| Scout | recon | Research & Intel | gpt-4.1-mini | Ops |
| Vault | ledger | Finance & KPIs | gpt-4.1-mini | Ops |
| Zion | pastor-zion | Spiritual Advisor | gpt-4.1-mini | Ops |
| Core | main | Default Fallback | gpt-4.1-mini | Ops |

## Communication Flow
Jon → Jarvis → [Aria routes] → Agent → Jarvis compiles → Jon

## Key Integrations
- OpenClaw: Agent orchestration platform
- War Room API: http://localhost:3700 (deliverable tracking)
- Vault: /Users/apex/.openclaw/vault (file storage)
- Telegram: Primary communication channel

## Status: COMPLETE
