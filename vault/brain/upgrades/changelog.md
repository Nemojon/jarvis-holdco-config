# SYSTEM CHANGELOG

Record of all implemented upgrades.

---

## 2026-04-04 — CONTEXT COMPACTION FOR FLEET

**Proposal source:** Agent Lab — 10/11 agents flagged for context bloat (≥8 items)

**Files changed:**
- `/Users/apex/.openclaw/scripts/bloat-check.js` — Added `--compact` flag
- `/Users/apex/.openclaw/scripts/compaction-nightly.js` — New nightly compaction pipeline
- `/Users/apex/.openclaw/scripts/dead-letter.sh` — PATH already correct (no change needed)

**Changes:**
1. **`--compact` flag in bloat-check.js:** When passed, automatically calls `compactAgent()` for every agent with ≥8 items. Uses `openclaw sessions compact` CLI; falls back to writing a `.compact-requested` marker file in the agent's workspace if CLI is unavailable.
2. **`compactionAgent()` function** in bloat-check.js: Logs all results to `~/.openclaw/logs/compaction-nightly.log`.
3. **`compaction-nightly.js`:** New standalone script that runs the full compaction pipeline — bloat check → report → recommendations → compact all bloated agents → write per-agent rolling `compaction-summary.md`. Designed for cron or dead-letter.sh wrapper. Supports `--dry-run`.
4. **Rolling summarization:** Each compacted agent gets a `compaction-summary.md` in its workspace directory with a dated log of compaction runs.
5. **dead-letter.sh PATH:** Already contains `export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"` — no change needed.

**Expected outcome:** Nightly compaction prevents context bloat accumulation across the fleet; `--compact` flag enables on-demand intervention.

---

## 2026-04-04 — QUICK WIN: Date filtering + source recalibration for nightly research pipeline

**File:** `/Users/apex/.openclaw/scripts/agent-lab-nightly.js`

**Changes:**
1. **Date filter added (Step 1b):** New `isItemFresh()` + `filterFresh()` functions skip any RSS item older than 30 days. Uses `pubDate` field; falls back to URL year heuristic (e.g. `/2021/` → stale). Items without parseable dates are allowed through.
2. **HuggingFace source replaced:** `huggingface.co/blog/feed.xml` (returning 2021-era posts) swapped for `huggingface.co/papers.rss` (daily HF Papers feed — current arxiv hits).
3. **LangChain RSS URL fixed:** `blog.langchain.dev/rss/` → `blog.langchain.dev/feed` (was returning Invalid URL errors).

**Expected outcome:** 0-recommendations-per-night streak ends; pipeline should surface 3-5 actionable items nightly from current sources only.

**Proposal source:** Agent Lab proposals active.md, 2026-04-04
2026-04-05: Fixed agent cron jobs by auditing all OpenClaw CLI uses for deprecated commands, validating config (removed forceIPv4), and running openclaw doctor. All automation restored. Minor config warning remains (disabled plugin searxng). No system health risks.
- 2026-04-07: Hardened cron execution by updating `scripts/dead-letter.sh` to verify the OpenClaw CLI at startup and by switching legacy cron/template examples to `/opt/homebrew/bin/openclaw agent ...` instead of brittle PATH-dependent or deprecated `send` patterns. Verified with `bash -n` and `openclaw doctor`.
