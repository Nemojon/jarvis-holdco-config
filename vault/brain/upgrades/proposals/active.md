# Active upgrade proposals — 2026-04-11

## UPGRADE PROPOSAL 2026-04-11
- **What:** Fleet-wide managed-agents doctrine injection using the Claude Managed Agents cookbook patterns.
- **Why:** The nightly scan surfaced a strong signal (`feat(managed_agents): add Claude Managed Agents cookbooks (#508)`, relevance 0.90). This is the cleanest leverage point: standardize proven orchestration, handoff, and self-repair patterns across the fleet instead of letting each agent improvise.
- **Effort:** MEDIUM
- **Implementation notes for Cipher:**
  - Add the new cookbook patterns to shared doctrine / agent memory for the core fleet.
  - Prioritize `data_analyst_agent`, `slack_data_bot`, `sre_incident_responder`, and the guided repair/tutorial workflows.
  - Start with a shared reference doc, then fold the highest-value patterns into target-agent prompts/memory.
  - Measure impact by rerunning Agent Lab and comparing task decomposition quality, handoff consistency, and recovery from failing tasks.
