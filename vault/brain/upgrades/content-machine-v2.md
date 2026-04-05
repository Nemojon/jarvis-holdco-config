# Content Machine v2 — Deployed April 5, 2026

## Version Tag
**v2** — Rollback available at:
- `~/.openclaw/cron/jobs.v1-backup.json`
- `~/.openclaw/vault/brain/skills/content-creation.v1-backup.md`

## Changes Deployed

### Modified Cron Jobs
1. **Content Pipeline Prep — Echo (Silent)** — Upgraded from 3 LinkedIn drafts → 10-piece content brief (Jon angles + BSQ client briefs + company brand). Timeout 240→600.
2. **MORNING COMMAND** — Added 4 new sections: Content Brief, BSQ Client Briefs, BSQ Account Scan, Client Signals.

### New Cron Jobs
3. **Client Prospecting Scanner — Scout (Silent)** — Daily 6:30 AM. Hunts for Biptap/1TXO clients (crypto cards, banking) and BSQ clients (branding). Writes to client-signals-YYYY-MM-DD.md.
4. **Afternoon Repurpose — Echo (Silent)** — Daily 2 PM. 2 fresh angles + 1 reactive hot take + 1 engagement post. Delivered to Telegram.
5. **Sunday Viral Carousel Pack — Echo** — Sunday 7 AM. Scans viral carousels, produces 5 carousel ideas across 3 pillars (AI/Productivity, Entrepreneurship, Manifestation/LOA). Uses GPT-5.3-codex. Delivered to Telegram.

### New Files
- `~/.openclaw/workspace-signal/carousel-pillars.md` — Pillar definitions, ICP, aesthetic guide

### Cron Schedule (Content Machine v2)
| Time | Job | Agent |
|------|-----|-------|
| 05:50 | CMO Daily Prep (BSQ account scan) | Luna |
| 06:00 | Morning Intel Prep | Scout |
| 06:10 | Content Brief Package (10 pieces) | Echo |
| 06:30 | Client Prospecting Scanner | Scout |
| 07:30 | MORNING COMMAND (consolidated delivery) | Jarvis |
| 14:00 | Afternoon Repurpose (4 pieces) | Echo |
| Sunday 07:00 | Viral Carousel Pack (5 carousels) | Echo |

### Rollback Procedure
```bash
cp ~/.openclaw/cron/jobs.v1-backup.json ~/.openclaw/cron/jobs.json
cp ~/.openclaw/vault/brain/skills/content-creation.v1-backup.md ~/.openclaw/vault/brain/skills/content-creation.md
openclaw gateway restart
```

## Modules (can disable individually)
To disable any module, use: `openclaw cron disable <job-id>`
- Client Prospecting Scanner: `8146b8f1-f370-4d86-a49e-7dc8351d27c6`
- Afternoon Repurpose: `84e90e2e-9ae8-4787-8b61-1b88c6681b76`
- Sunday Carousel Pack: `de5113cd-de22-4256-ae0a-5962e1d422ba`
