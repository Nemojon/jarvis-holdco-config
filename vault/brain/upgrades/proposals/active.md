# Active Upgrade Proposals

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
