# HoldCo Agent Architecture
Version: 1.0 | Date: 2026-02-27

## Agent Fleet (14 Active) — Updated 2026-04-06
| Agent | ID | Role | Model | Layer |
|-------|----|------|-------|-------|
| Jarvis | orion | COO / Command | gpt-5.4-pro | Command |
| Nova | apex | Co-CEO / Strategy | gpt-5.4-pro | Command |
| Cipher | cto | CTO / Architecture | gpt-5.4 | Command |
| Luna | aurora | CMO / Marketing | gpt-5.4 | Function |
| Echo | signal | Content & Comms | gpt-5.4 | Function |
| Rex | hunter | Pipeline & BD | gpt-5.4 | Function |
| Scout | recon | Research & Intel | gpt-5.4 | Function |
| Vault | ledger | Finance & KPIs | gpt-5.4 | Function |
| Lex | counsel | Compliance & Legal | gpt-5.4 | Function |
| Aria | atlas | Task Router & Ops | gpt-5.4 | Ops |
| Zion | pastor-zion | Chief of Staff | gpt-5.4-mini | Ops |
| Agent Lab | agent-lab | Meta-Improvement | gpt-5.4-mini | Ops |
| Core | main | Default Fallback | gpt-5.4-mini | Ops |
| Council Sage | council-sage | Advisory | gpt-5.4 | Advisory |
| Council Oracle | council-oracle | Advisory | gemini-2.5-pro | Advisory |

## Communication Flow
Jon → Jarvis → [Aria routes] → Agent → Jarvis compiles → Jon

## Key Integrations
- OpenClaw: Agent orchestration platform
- War Room API: http://localhost:3700 (deliverable tracking)
- Vault: /Users/apex/.openclaw/vault (file storage)
- Telegram: Primary communication channel

## Status: COMPLETE
