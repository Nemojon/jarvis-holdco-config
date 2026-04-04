# Active Upgrade Proposals

---

## ✅ IMPLEMENTED — 2026-04-04 (by Cipher)

**What:** Add date-based filtering + source recalibration to the nightly research pipeline to eliminate stale content ingestion

**Why:** Last night's scan processed 583 items but only 2 scored above 0.3, and 0 new recommendations were generated. The culprit: the HuggingFace blog feed is returning years-old posts (BERT 101, Gradio 3.0, Wav2Vec2 tutorials — all from 2021-2022). The pipeline is wasting cycles and producing no signal. This is why we've had stretches of 0 recommendations — the research engine is blind to what's actually happening in AI right now.

**Effort:** QUICK WIN

**Implementation notes for Cipher:**
- In `agent-lab-nightly.js`, add a date filter in Step 3/4 (scoring): skip any item whose `pubDate` or `isoDate` is older than 30 days. Most RSS feeds include publication dates.
- If pubDate is missing, use the item's URL or title heuristic (year in URL like `/2021/` → skip).
- Also audit/replace the HuggingFace source — instead of `huggingface.co/blog` RSS (returns old posts), target `huggingface.co/papers` daily feed or the HF Papers newsletter which surfaces current arxiv hits.
- Add `https://simonwillison.net/atom/everything/` as a supplemental source — Simon covers bleeding-edge LLM tooling daily.
- Consider adding `https://www.anthropic.com/research` RSS if available.
- Secondary: the LangChain RSS URL has been failing with `Invalid URL` — check `blog.langchain.dev/rss` vs `blog.langchain.dev/feed`.

**Expected outcome:** Recommendations per night should go from ~0 to 3-5 actionable items; scoring distribution will shift meaningfully above 0.5.

**Source signal:** 0/583 items actionable last night; reviewed scored items confirm 2021-era HF blog content dominating the feed

---

## UPGRADE PROPOSAL — 2026-04-03

**What:** Implement automated context compaction for the agent fleet using Anthropic's context engineering strategies (memory summarization + compaction pipeline)

**Why:** 10 out of 11 core agents are currently flagged for context bloat (10–11 items each, above the 8-item recommendation threshold). This directly degrades response quality as stale context crowds out fresh signal, and inflates token costs on every agent turn. The Anthropic cookbook just shipped a new "context engineering strategies" entry (scored 0.70 this week) covering memory, compaction, and summarization — timing is perfect to implement this properly.

**Effort:** MEDIUM

**Implementation notes for Cipher:**
- The Anthropic cookbook commit `feat(tool_use): add context engineering strategies cookbook` covers three patterns: rolling summarization, selective retention, and compaction triggers
- For our fleet: add a compaction step to the nightly pipeline (agent-lab-nightly.js, Step 5/Bloat) — when an agent hits ≥8 items in queue, trigger a summarization pass that collapses the oldest 5 items into a single "digest" entry, preserving signal while cutting token load
- The nightly bloat check already identifies candidates (10 flagged tonight); just needs a compaction action wired in after the flag
- Consider a `--compact` flag on the bloat-check.js script to trigger on-demand
- Secondary: fix the LangChain RSS URL (currently `Invalid URL` — blog.langchain.dev/rss/ may need to be `blog.langchain.dev/feed` or similar) to restore that research source
- Also worth noting: dead-letter.sh PATH failures (`openclaw: command not found`) from March 27-30 indicate shell scripts need explicit PATH exports — add `export PATH=/opt/homebrew/bin:$PATH` at top of dead-letter.sh

**Source signal:** Anthropic cookbook commit scored 0.70 (2026-03-31); fleet bloat confirmed 10/11 agents flagged tonight
