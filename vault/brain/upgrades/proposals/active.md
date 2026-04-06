UPGRADE PROPOSAL [2026-04-06]

What: Systematic adoption of "Mixture of Experts" (MoEs) technique in all transformer-based agent models used across the fleet. This is based on the high signal in the latest research pipeline scan: MoEs now deliver state-of-the-art performance for large models with improved efficiency, throughput, and robustness. Applies both to inference and training pipelines.

Why: Implementing MoEs can unlock significant improvements in model scaling, processing speed, and operational efficiency. Recent research confirms tangible SOTA performance and cost reductions on large deployments—particularly relevant for OpenClaw's multi-agent inference & coding workloads.

Effort: MEDIUM — Requires updates to core model configs, re-benchmarking, and careful evaluation of routing heuristics (but infra is already compatible; no multi-month rewrite required).

Implementation notes for Cipher:
- Audit existing transformer deployments for MoE compatibility (HuggingFace, Anthropic, OpenAI families likely ready)
- Stage migration in sandbox, then fleet-wide
- Prioritize agents running costliest workloads (Code, Reasoning, Vision)
- Run re-benchmarks before/after for objective reporting
- Review and adapt routing logic post-migration for optimal MoE performance
