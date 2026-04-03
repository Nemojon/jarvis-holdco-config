# BOOT MANIFEST
Updated: 2026-04-03

Documents which files each agent loads at boot via workspace CLAUDE.md brain-check protocol.

## All Agents (shared core — read in this order):
1. Own workspace `SOUL.md` (who you are, operational mandate)
2. Own workspace `USER.md` (who Jon is, preferences)
3. `/vault/brain/STATE.md` (current priorities and operating state)
4. `/vault/brain/corrections/active.md` (active corrections — mistakes to avoid)
5. `/vault/brain/lessons/active.md` (lessons learned by all agents)
6. `/vault/brain/MASTER.md` (standing directives, what Jon hates/loves)
7. `/vault/brain/skills/INDEX.md` (skill playbooks — check for relevant procedures)
8. Own workspace `MEMORY.md` (personal learnings)
9. `/vault/brain/agents/{name}.md` (your brain memory — cross-agent knowledge)

## Per Agent (additional reads):
- **Jarvis (orion):** + tasks/queue.md, tasks/in-progress.md
- **Aria (atlas):** + tasks/queue.md (for routing)
- **Nova (apex):** + feedback/active.md (for quality gate context)
- **Zion (pastor-zion):** + corrections/broadcast-log.md, all agents/*.md (maintenance responsibility)
- **Agent Lab:** + upgrades/proposals/active.md, system/health.md

## Write-Back Protocol (after every task):
1. Own workspace `MEMORY.md` — personal learning
2. `/vault/brain/agents/{name}.md` — anything other agents should know
3. `/vault/brain/lessons/active.md` — if a new lesson was learned
4. `/vault/brain/feedback/active.md` — if Jon gave feedback
