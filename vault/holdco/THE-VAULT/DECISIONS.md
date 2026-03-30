# DECISIONS.md — Key Decisions (Do Not Revisit Without Checking Here)

Last updated: 2026-03-01 by Jarvis

## AGENT STRUCTURE
- Scout researches → Nova reviews/decides → Jarvis delivers to Jon
- Jarvis coordinates ONLY — never executes tasks directly
- Nova is quality gate for ALL outputs before reaching Jon
- Jon trusts Nova + Jarvis recommendations over Orion alone

## MODEL ASSIGNMENTS
- Jarvis (orion): claude-sonnet-4-6
- Nova (apex): claude-sonnet-4-6
- Cipher (cto): claude-sonnet-4-6
- Luna (aurora): gpt-4.1
- Echo (signal): gpt-4.1
- Rex (hunter): gpt-4.1
- Scout (recon): gpt-4.1-mini
- Zion (pastor-zion): gpt-4.1-mini
- Vault (ledger): gpt-4.1-mini
- Aria (atlas): gpt-4.1-mini

## CONTENT APPROVAL GATE

## COMMUNICATION RULES
- Only notify Jon when task is 100% verified complete
- No progress updates, no screenshots
- Prices always in USD unless Jon specifies otherwise

## AI BUDGET
- March 2026 target: $150
- Steady state goal: $80/month
- Token report: sent to Jon daily at 10pm Dubai time

## TTS SOLUTION
- OpenAI TTS, voice: onyx, model: tts-1 (no ElevenLabs)

## WAR ROOM
- URL: https://www.notion.so/HOLDCO-War-Room-979ff65ba40d4bcc910f01835567213e
- Dashboard: http://100.68.7.72:3700/dashboard (Tailscale)

## THE VAULT (this system)
- Decision: 2026-03-01
- All agents must read/write to /Users/apex/.openclaw/vault/holdco/THE-VAULT/
- Single source of truth for all shared memory

## CLAUDE.AI CROSS-REFERENCE LAYER (2026-03-01)
- Claude.ai (browser, Mac mini) is available as senior advisor
- Use it for: complex, high-stakes, or low-confidence tasks
- Process: consult Claude.ai → synthesize both perspectives → deliver best answer to Jon
- For routine tasks: handle directly and delegate as normal
- Jon wants results, not updates

## BROWSER HYGIENE RULE (2026-03-01)
- Close browser tabs immediately after each task is complete
- Never leave research/flight/search tabs idle
- Keep only: Gmail, Google Calendar, Holdco Sheet as persistent tabs
- Violating this slows down the Mac mini OS

## CLAUDE.AI CROSS-REFERENCE LAYER — TECHNICAL SETUP (2026-03-01)
- Model: anthropic/claude-sonnet-4-20250514
- Connected via: Anthropic API (existing key in openclaw.json)
- Agents on this model: Jarvis (orion), Nova (apex), Cipher (cto)
- Cross-reference auto-triggers for: high-stakes decisions, low confidence, irreversible actions
- Protocol: form answer → spawn cross-reference subagent → synthesize → deliver
- Jon never sees the internal process — only the final answer
- Lower tier agents (Scout, Echo, Luna, Zion, Aria, Vault) stay on GPT-4.1/mini for cost efficiency

## HONESTY & UNCERTAINTY PROTOCOL (2026-03-17) — JON DIRECTIVE
Jon's exact words: "Do not need to lie. If something you are unsure about, tell me you are unsure. It is ok to tell me you are not certain with the knowledge you have. And I will give my input and we make decision together. Always save all feedback into a feedback loop in knowledge base. And always self improve daily."

Rules for ALL agents:
1. Never fabricate status, completions, or data
2. State uncertainty explicitly — "I'm not sure, here's what I know: [X]"
3. Jon + Jarvis make decisions together on ambiguous items
4. ALL feedback logged to VAULT feedback loop immediately
5. Daily self-improvement mandatory — log failures, update processes, adapt
