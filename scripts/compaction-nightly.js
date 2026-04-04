#!/usr/bin/env node
// compaction-nightly.js — Nightly context compaction for bloated agents
// Runs bloat-check on all agents, compacts any agent with ≥8 bloat items
// Logs results to ~/.openclaw/logs/compaction-nightly.log
//
// Usage:
//   node compaction-nightly.js           — Run compaction pipeline
//   node compaction-nightly.js --dry-run — Check only, no compaction
//
// Designed to be called from cron or dead-letter.sh wrapper.
// Created: 2026-04-04

const fs = require("fs");
const path = require("path");

const OPENCLAW = path.join(process.env.HOME, ".openclaw");
const LOG_PATH = path.join(OPENCLAW, "logs/compaction-nightly.log");
const BLOAT_CHECK = path.join(OPENCLAW, "scripts/bloat-check.js");
const REC_THRESHOLD = 8;

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------
function log(msg) {
  const line = `${new Date().toISOString()} | ${msg}`;
  console.log(line);
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.appendFileSync(LOG_PATH, line + "\n");
}

// ---------------------------------------------------------------------------
// Main pipeline
// ---------------------------------------------------------------------------
async function main() {
  const isDryRun = process.argv.includes("--dry-run");

  log("=".repeat(60));
  log(`COMPACTION PIPELINE START — ${new Date().toISOString().slice(0, 10)} ${isDryRun ? "(dry-run)" : ""}`);

  // Load bloat-check module
  if (!fs.existsSync(BLOAT_CHECK)) {
    log(`ERROR: bloat-check.js not found at ${BLOAT_CHECK}`);
    process.exit(1);
  }

  const {
    countAgentItems,
    generateReport,
    createRecommendations,
    compactAgent,
    CORE_AGENTS,
  } = require(BLOAT_CHECK);

  // STEP 1: Run bloat-check on all agents
  log("--- STEP 1: BLOAT CHECK ---");
  const results = CORE_AGENTS.map((id) => {
    const r = countAgentItems(id);
    log(`BLOAT: ${id} — ${r.total} items (tools=${r.toolCount}, skills=${r.skillCount})`);
    return r;
  });

  // STEP 2: Generate and log report
  log("--- STEP 2: REPORT ---");
  const report = generateReport(results);
  log("REPORT:\n" + report);

  const bloated = results.filter((r) => r.total >= REC_THRESHOLD);
  const flagged = results.filter((r) => r.total >= 5 && r.total < REC_THRESHOLD);

  log(`Agents bloated (≥${REC_THRESHOLD}): ${bloated.length}`);
  log(`Agents flagged (≥5): ${flagged.length}`);

  // STEP 3: Create recommendations for bloated agents (re-use bloat-check logic)
  log("--- STEP 3: RECOMMENDATIONS ---");
  const recCount = createRecommendations(results, false);
  log(`RECOMMENDATIONS: ${recCount} new recommendations created`);

  // STEP 4: Compact bloated agents
  log("--- STEP 4: COMPACTION ---");
  if (bloated.length === 0) {
    log("COMPACT: No agents over threshold — nothing to compact.");
  } else if (isDryRun) {
    log(`COMPACT (dry-run): Would compact ${bloated.length} agents: ${bloated.map((r) => r.agentId).join(", ")}`);
  } else {
    log(`COMPACT: Processing ${bloated.length} bloated agents...`);
    const compactResults = [];

    for (const r of bloated) {
      log(`COMPACT: Starting ${r.agentId} (${r.total} items)...`);
      const result = compactAgent(r.agentId, false);
      compactResults.push(result);

      // Rolling summary entry per agent
      const summaryPath = path.join(OPENCLAW, `workspace-${r.agentId}`, "compaction-summary.md");
      const wsDir = path.join(OPENCLAW, `workspace-${r.agentId}`);
      if (fs.existsSync(wsDir)) {
        const entry = `\n## ${new Date().toISOString().slice(0, 10)} — Compaction Run\n- Items at time of compaction: ${r.total} (tools=${r.toolCount}, skills=${r.skillCount})\n- Status: ${result.status}\n- Triggered by: compaction-nightly.js\n`;
        const header = fs.existsSync(summaryPath) ? "" : "# Compaction History\n\nRolling log of nightly compaction runs for this agent.\n";
        fs.appendFileSync(summaryPath, header + entry);
        log(`SUMMARY: Wrote compaction summary to ${summaryPath}`);
      }
    }

    // Report results
    const ok = compactResults.filter((r) => r.status === "ok").length;
    const markers = compactResults.filter((r) => r.status === "marker").length;
    const errors = compactResults.filter((r) => r.status === "error").length;

    log(`COMPACT SUMMARY: ${ok} compacted, ${markers} markers written, ${errors} errors`);
    log(`COMPACT DETAIL: ${compactResults.map((r) => `${r.agentId}=${r.status}`).join(", ")}`);
  }

  log("COMPACTION PIPELINE COMPLETE");
  log("=".repeat(60));
}

main().catch((e) => {
  log(`PIPELINE FATAL: ${e.message}`);
  console.error(e);
  process.exit(1);
});
