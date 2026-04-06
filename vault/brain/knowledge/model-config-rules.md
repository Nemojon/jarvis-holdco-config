# Model Configuration Rules — PERMANENT

## 4-Location Checklist (ALL must be updated for any model change)
1. `~/.openclaw/openclaw.json` — agent primary + fallbacks + defaults + models registry
2. `~/.openclaw/cron/jobs.json` — payload model overrides (THESE OVERRIDE AGENT CONFIG)
3. `~/.openclaw/agents/*/sessions/sessions.json` — cached model from previous runs
4. Agent docs (identity.md, soul.md, CLAUDE.md) — text references to models

## Current Fleet Model Map (Apr 6, 2026)
- **Pro (gpt-5.4-pro):** orion, apex
- **Flagship (gpt-5.4):** atlas, hunter, recon, signal, ledger, aurora, cto, counsel, council-sage
- **Utility (gpt-5.4-mini):** main, agent-lab, pastor-zion
- **Gemini (gemini-2.5-pro):** council-oracle

## BANNED Models (removed from system)
- gpt-4.1, gpt-4.1-mini — removed from registry, fallbacks, and all configs

## Guard Rails
- COR-002 fleet doctrine rule: no agent may modify model configs
- model-guard.sh: runs every 3h, alerts Jon on Telegram if contamination detected
- CTO + Agent Lab: hard constraint in identity.md against model changes

## Lesson Learned
On Apr 5-6, 2026, the fleet ran on gpt-4.1 because cron job overrides were never updated during a model upgrade. Jon lost an entire day. This must never happen again.
