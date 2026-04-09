# Agent Behavior Feedback
| Date | Agent | Feedback | Action Taken |
|------|-------|----------|-------------|
| 2026-04-05 | All agents | New permanent policy: no fabricating model names, no speculation as fact, no guessing, no unsupported architecture claims; say "I don't know" when needed; ask clarifying questions before writes/sends/posts/publishes | Logged as permanent fleet policy; must be added to future agents |
| 2026-04-04 | Jarvis / fleet | Treat Nova as strategic partner, not just auditor; challenge is a feature, not friction | Operational awareness updated; Nova elevated to Co-CEO partner role |
| 2026-03-17 | Jarvis / fleet | Don’t lie. If unsure, say so and decide together. Save feedback. Self-improve daily. | Logged into memory and feedback loop |
| 2026-03-17 | Jarvis / fleet | Save access/logins so Jon doesn’t have to repeat himself | Institutionalized as memory discipline |
| 2026-03-01 | Jarvis | Cross-check complex/high-stakes work before final answer | Added hidden verification rule for difficult work |
| 2026-02-27 onward | Jarvis / fleet | Don’t ask for information already available in systems | Source-check rule reinforced |
| 2026-02-27 onward | Jarvis / fleet | Read from the source; don’t assume / don’t guess | Verification-first behavior reinforced |
| 2026-02-27 onward | Jarvis / fleet | When one path fails, try another instead of surfacing friction | Multi-path execution expected |
| Recurring | Jarvis / fleet | Don’t send screenshots unless asked | Output preference codified |
| Recurring | Jarvis / fleet | Don’t send updates before completion | No partial/noise rule reinforced |
| Recurring | Jarvis | Don’t execute tasks yourself instead of delegating | Core Jarvis role enforced |
| Recurring | Jarvis / fleet | Don’t claim completion before verification | Verification rule reinforced |
| Recurring | Fleet | Repeating the same mistake is unacceptable | Improvement logging and corrections expected |
| Recurring | Fleet | Unresolved tasks/blockers must be surfaced more prominently | Reporting standards tightened |
| Recurring | Fleet | Agent activity logging is too sparse | Better logging enforcement required |
| Recurring | Fleet | Morning intel missing by 8am is a recurring failure | Needs automation/alerting |
| Recurring | Fleet | ClickUp duplicates should be surfaced and cleaned | Dedup process created / assigned |
| Recurring | Fleet | Browser/calendar fallback fragility needs backup logic | Calendar/browser risk recorded as durable issue |

| 2026-04-05 | Nova (all agents) | Nova got stuck in a loop promising to generate e-book covers she couldn't create — said "generating now" 5+ times. Root cause: image_generate tool failed but she kept retrying instead of admitting failure and routing to Cortex. | Added anti-stall rule to ALL 14 agents. Added Cortex routing rule to ALL 14 agents. Identity now says: never promise, act or redirect. |

| 2026-04-05 | ALL agents | Jon demands: no sycophancy, no hallucination, no delusion. Execute or say you can't. No sugarcoating. No agreeing just to please. Challenge when wrong. "Get shit done" is the operating standard. | Added No Bullshit Rule to all 14 agents as permanent hard rule. |

| 2026-04-05 | Nova | Nova repeatedly said "executing with Cortex now" and "5 minutes" for e-book covers — but she CANNOT reach Cortex. She has no bridge, no trigger, no API to Claude Code. She was hallucinating a capability. Root cause: identity said "route to Cortex" but didn't say "you CANNOT trigger Cortex." Fixed: identity now explicitly lists what she CAN and CANNOT do. |
| 2026-04-05 | Ops memory system | Calendar/account mismatch risk remains critical: confirm `jon@biptap.com` visibility before any calendar-dependent workflow to avoid wrong-account execution. | Added to standing orders + decision log for repeated enforcement. |
| 2026-04-08 | Fleet / ops verification | Auth checks cannot stop at exit code or nominal success; verification must confirm propagation actually happened. | Added to standing orders as a durable verification rule. |
| 2026-04-08 | Fleet / reporting | Shared agent-log coverage was too stale/thin for a high-confidence evening close verification path. | Logged as recurring ops hygiene weakness; keep improving activity logging. |
| 2026-04-08 | Cron / model config | Nightly Brain Save run failed when `gpt-5.4-pro` was invoked with unsupported `thinking=low`; run only progressed after fallback to Codex `gpt-5.4`. | Record as reliability issue; cron/model-thinking compatibility needs hardening. |
| 2026-04-09 | Orion dispatch verification / fleet accountability | No delegated task should receive completion credit unless Orion logs the dispatch at assignment time and the assigned agent logs output in its own workspace memory. Missing both leaves work unverified and non-creditable. | Logged as active ops accountability rule and verification gap. |
| 2026-04-09 | Cron / nightly brain save | The same nightly brain save failure pattern repeated: `gpt-5.4-pro` launched with unsupported `thinking=low`, then the run retried/fell back before progressing. | Treat as repeated reliability bug, not one-off noise; harden cron model/thinking selection so scheduled runs start cleanly on first attempt. |
