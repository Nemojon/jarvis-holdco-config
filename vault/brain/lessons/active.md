# ACTIVE LESSONS

Unresolved lessons from self-improvement loop.
Repeat count > 3 = escalation required.

---

## LES-001 — Calendar Scheduling: Browser Only (2026-03-20)
**Context:** Jon explicitly rejected .ics file approach multiple times.
**Lesson:** Calendar events must be created via jarvis@biptap.com Google Calendar in browser. Create event, add attendees (jon@biptap.com + client), send invite. No .ics files, no email workarounds, no asking for clarification if info was already given. Default: 1 hour, Google Meet link.
**Status:** Resolved — permanent rule locked in.

## LES-002 — Agent Health: Silent Failures Are Invisible (2026-03-20)
**Context:** Zion health report showed 5 of 9 agents stuck with no logs for 48+ hours (Echo, Rex, Cipher, Lex, Vault).
**Lesson:** Agents that go silent are effectively dead. A heartbeat or activity log check must run daily. Any agent with no activity for 24h should be flagged; 48h+ should trigger auto-restart or escalation. Silence is not stability — it is failure.
**Status:** Active — monitoring improvement needed.

## LES-003 — Delegation Over Execution (2026-03-19)
**Context:** Jon standing directive confirmed during system setup.
**Lesson:** Jarvis must never execute tasks directly. Every task gets delegated to the appropriate specialist agent. Jarvis coordinates, tracks, and quality-gates. Executing personally is a failure mode, not a workaround.
**Status:** Permanent rule.

## LES-004 — Evening Summary Depends on Morning Intel (2026-03-27)
**Context:** Morning intel file missing for 3 consecutive days (Mar 24, 25, 27).
**Lesson:** The evening summary is only as good as the morning context it references. Without the morning intel file, the evening summary cannot flag missed opportunities or compare planned vs. actual. The morning file is not optional — it is a dependency.
**Status:** Active — needs automated enforcement (see COR-002).

## LES-005 — Consistent Daily Delivery Is the Baseline (2026-03-24)
**Context:** Self-improvement log noted systematic daily delivery of summaries and check-ins as a win.
**Lesson:** Showing up on schedule every day is the minimum expectation, not an achievement. The value is in the quality of insight surfaced, not the act of delivering. Focus improvements on depth and actionability, not on consistency (which should be automatic).
**Status:** Active.

## LES-006 — ClickUp Task Deduplication (2026-03-27)
**Context:** Speaking applications appeared as both "urgent" and "to do" — duplication not caught.
**Lesson:** When pulling tasks from ClickUp, deduplicate by task ID before presenting. Flag any task that appears in multiple status columns. Jon should never see the same task listed twice in different priority buckets.
**Status:** Active — needs implementation.

## LES-007 — Chrome Must Be Running for Calendar Snapshots (2026-03-27)
**Context:** Chrome was not running on Mac Mini at 9pm; calendar snapshot unavailable for evening summary.
**Lesson:** Any cron job that depends on browser state must verify browser is running before execution. If Chrome is down, either launch it or fall back to Google Calendar API. Do not silently skip calendar data.
**Status:** Active — needs fallback implementation.

## LES-008 — Security Alerts Require Immediate Surfacing (2026-03-20)
**Context:** Google password change on jonathan.lyt89@gmail.com (Mar 18) and new sign-in to contact@thejonathanlow.com (Mar 19) detected.
**Lesson:** Security-related events (password changes, new sign-ins, billing changes) must be surfaced to Jon within the same day they are detected, not buried in a morning brief. These are priority-zero items.
**Status:** Active.

## LES-009 — Agent Vault Logs Are Sparse (2026-03-27)
**Context:** No agent log entries for major project deliverables on multiple days.
**Lesson:** Every major deliverable completed by any agent must have a corresponding log entry in the vault. Sparse logs make it impossible to audit what was actually done. Logging is not overhead — it is accountability.
**Status:** Active — repeat offender (flagged Mar 24, 25, 27).

## LES-010 — Verify Actionable URLs Before Delivery (2026-03-30)
**Context:** Scout's DFS report listed a speaker application URL (get-involved → Speak) that actually loads a ticket purchase page. The #1 action item in the report pointed to a potentially dead end.
**Lesson:** Any report that includes a "do this now" action with a URL must have that URL verified as working and leading to the correct destination. Broken or misleading links in the #1 action item destroy report credibility. Scout and all agents producing actionable research must click-test every URL they include.
**Status:** Active.

## LES-011 — Calendar Browser Redirects to Wrong Account (2026-04-04)
**Context:** Navigating to calendar.google.com/calendar/u/1/ consistently redirects to /u/0 (jonathan.lyt89ai@gmail.com AI agent account instead of jon@biptap.com). Calendar data for Jon's account is invisible.
**Lesson:** Browser Google account order is not stable. Need to either: (a) bookmark/force the correct account via authuser param, (b) verify which account loaded after navigation, or (c) add jon@biptap.com calendar to the AI agent account as a shared calendar. This is a repeat of the Mar 31 finding — escalate to corrections.
**Repeat count:** 2
**Status:** Active — needs fix.

## LES-012 — Cron Delivery Targeting Still Broken (2026-04-04)
**Context:** MORNING COMMAND and STATE.md cron jobs failing with "Telegram recipient @heartbeat could not be resolved." Delivery channel set to 'last' instead of explicit chat ID.
**Lesson:** All cron jobs that deliver to Jon must use explicit delivery config: channel=telegram, to=970413391. Using 'last' or '@heartbeat' causes silent delivery failures. Audit all cron delivery configs.
**Repeat count:** 1
**Status:** Active — needs cron config fix.

## LES-013 — Vault Token Monitor Chronic Timeouts (2026-04-04)
**Context:** Token Balance Monitor has 4 consecutive timeout errors. Browser-based billing page scraping is unreliable.
**Lesson:** Browser-based billing checks are fragile — pages load slowly, require auth, and timeout at 120-360s. Need either: (a) API-based balance checks, (b) increased timeout, or (c) a lighter-weight check method. Token spend visibility is a blind spot when this job fails.
**Repeat count:** 4 — ESCALATION THRESHOLD.
**Status:** Active — escalate to Cipher.
