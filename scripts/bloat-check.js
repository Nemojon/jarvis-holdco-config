#!/usr/bin/env node
// bloat-check.js — Standalone skill/tool/memory bloat monitor for all 11 agents
// Read-only against agent configs. Writes only to agent_lab_recommendations.
//
// Usage:
//   node bloat-check.js            — Full report + recommendations
//   node bloat-check.js --json     — JSON output
//   node bloat-check.js --quiet    — Counts only, no recommendations
//   node bloat-check.js --compact  — Run report + auto-compact bloated agents (≥8 items)
//
// Also called from agent-lab-nightly.js step 5.
// Created: 2026-03-27
// Updated: 2026-04-04 — Added --compact flag

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const OPENCLAW = path.join(process.env.HOME, ".openclaw");
const DB = path.join(OPENCLAW, "memory/agent_lab.sqlite");
const CONFIG_PATH = path.join(OPENCLAW, "openclaw.json");
const LOG_PATH = path.join(OPENCLAW, "logs/bloat-check.log");

const CORE_AGENTS = [
  "apex", "atlas", "aurora", "cto", "hunter",
  "ledger", "main", "orion", "pastor-zion", "recon", "signal",
];

const FLAG_THRESHOLD = 5;
const REC_THRESHOLD = 8;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function log(msg) {
  const line = `${new Date().toISOString()} | ${msg}`;
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.appendFileSync(LOG_PATH, line + "\n");
}

function esc(s) {
  return s ? String(s).replace(/'/g, "''") : "";
}

function dbExec(sql) {
  return execSync(`sqlite3 "${DB}" "${sql.replace(/"/g, '\\"')}"`, {
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
  }).trim();
}

function dbQuery(sql) {
  try {
    const result = execSync(`sqlite3 -json "${DB}" "${sql.replace(/"/g, '\\"')}"`, {
      encoding: "utf8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    return JSON.parse(result || "[]");
  } catch {
    return [];
  }
}

// ---------------------------------------------------------------------------
// Count tools, skills, and memory entries per agent
// ---------------------------------------------------------------------------
function countAgentItems(agentId) {
  const agentDir = path.join(OPENCLAW, "agents", agentId);
  const wsDir = path.join(OPENCLAW, `workspace-${agentId}`);

  const tools = [];
  const skills = [];
  const memoryEntries = [];

  // --- TOOLS: lines referencing executable commands in CLAUDE.md / workspace CLAUDE.md ---
  const toolPatterns = [
    /^\s*[-*]\s+`[^`]*(?:node|python|bash|exec|sh|curl|openclaw)\s[^`]+`/gim,
    /^\s*[-*]\s+.*(?:tool|command):\s*`[^`]+`/gim,
    /^(?:Command|Run|Execute):\s*.+$/gim,
  ];

  for (const mdPath of [
    path.join(agentDir, "CLAUDE.md"),
    path.join(wsDir, "CLAUDE.md"),
  ]) {
    if (!fs.existsSync(mdPath)) continue;
    const content = fs.readFileSync(mdPath, "utf8");
    for (const pat of toolPatterns) {
      pat.lastIndex = 0;
      let m;
      while ((m = pat.exec(content)) !== null) {
        const line = m[0].trim().slice(0, 120);
        if (!tools.includes(line)) tools.push(line);
      }
    }
  }

  // --- SKILLS: H2/H3 sections in CLAUDE.md files that look like capabilities ---
  const skillPatterns = /^#{2,3}\s+(?!IDENTITY|FEEDBACK|MISTAKE|LESSONS|MANDATORY|CURRENT)(.+)/gm;

  for (const mdPath of [
    path.join(agentDir, "CLAUDE.md"),
    path.join(wsDir, "CLAUDE.md"),
    path.join(agentDir, "agent", "SOUL.md"),
  ]) {
    if (!fs.existsSync(mdPath)) continue;
    const content = fs.readFileSync(mdPath, "utf8");
    skillPatterns.lastIndex = 0;
    let m;
    while ((m = skillPatterns.exec(content)) !== null) {
      const name = m[1].trim();
      if (name && !skills.includes(name)) skills.push(name);
    }
  }

  // --- MEMORY: entries in the agent's SQLite memory DB ---
  const memDb = path.join(OPENCLAW, "memory", `${agentId}.sqlite`);
  if (fs.existsSync(memDb)) {
    try {
      const count = execSync(
        `sqlite3 "${memDb}" "SELECT COUNT(*) FROM chunks;"`,
        { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }
      ).trim();
      const fileCount = execSync(
        `sqlite3 "${memDb}" "SELECT COUNT(*) FROM files;"`,
        { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }
      ).trim();
      memoryEntries.push(`${count} chunks across ${fileCount} files`);
    } catch {}
  }

  const total = tools.length + skills.length;

  return {
    agentId,
    tools,
    skills,
    memoryEntries,
    toolCount: tools.length,
    skillCount: skills.length,
    memoryCount: memoryEntries.length ? parseInt(memoryEntries[0]) || 0 : 0,
    total,
  };
}

// ---------------------------------------------------------------------------
// Generate report
// ---------------------------------------------------------------------------
function generateReport(results) {
  const sorted = [...results].sort((a, b) => b.total - a.total);

  const lines = [];
  lines.push("╔══════════════════════════════════════════════════════════════╗");
  lines.push("║           AGENT BLOAT CHECK — " + new Date().toISOString().slice(0, 10) + "                    ║");
  lines.push("╠══════════════════════════════════════════════════════════════╣");
  lines.push("║ Agent          │ Tools │ Skills │ Memory │ Total │ Status   ║");
  lines.push("╠════════════════╪═══════╪════════╪════════╪═══════╪══════════╣");

  for (const r of sorted) {
    let status = "OK";
    if (r.total >= REC_THRESHOLD) status = "⚠ BLOAT";
    else if (r.total >= FLAG_THRESHOLD) status = "⚡ FLAG";

    const agent = r.agentId.padEnd(14);
    const tools = String(r.toolCount).padStart(5);
    const skills = String(r.skillCount).padStart(6);
    const mem = String(r.memoryCount).padStart(6);
    const total = String(r.total).padStart(5);
    const st = status.padEnd(8);
    lines.push(`║ ${agent} │${tools} │${skills} │${mem} │${total} │ ${st} ║`);
  }

  lines.push("╚══════════════════════════════════════════════════════════════╝");

  const flagged = sorted.filter((r) => r.total >= FLAG_THRESHOLD);
  const bloated = sorted.filter((r) => r.total >= REC_THRESHOLD);

  lines.push("");
  lines.push(`Agents flagged (≥${FLAG_THRESHOLD}): ${flagged.length}`);
  lines.push(`Agents bloated (≥${REC_THRESHOLD}): ${bloated.length}`);

  if (bloated.length > 0) {
    lines.push("");
    lines.push("BLOAT DETAILS:");
    for (const r of bloated) {
      lines.push(`  ${r.agentId} (${r.total} items):`);
      if (r.tools.length > 0) {
        lines.push("    Tools:");
        for (const t of r.tools) lines.push(`      - ${t.slice(0, 100)}`);
      }
      if (r.skills.length > 0) {
        lines.push("    Skills:");
        for (const s of r.skills) lines.push(`      - ${s}`);
      }
    }
  }

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Create recommendations for bloated agents
// ---------------------------------------------------------------------------
function createRecommendations(results, quiet = false) {
  const bloated = results.filter((r) => r.total >= REC_THRESHOLD);
  let created = 0;

  for (const r of bloated) {
    // Check if we already have a pending bloat rec for this agent today
    const today = new Date().toISOString().slice(0, 10);
    const existing = dbQuery(
      `SELECT id FROM agent_lab_recommendations WHERE target_agent='${r.agentId}' AND category='skill-bloat' AND status='pending' AND date(created_at)='${today}';`
    );
    if (existing.length > 0) {
      if (!quiet) console.log(`  Skip ${r.agentId} — already has pending bloat rec today (#${existing[0].id})`);
      continue;
    }

    const skillList = r.skills.map((s) => `• ${s}`).join("\n");
    const toolList = r.tools.map((t) => `• ${t.slice(0, 80)}`).join("\n");
    const description = `${r.agentId} has ${r.total} items (${r.toolCount} tools, ${r.skillCount} skills).\n\nSkills:\n${skillList}\n\nTools:\n${toolList}\n\nSuggestion: Review for consolidation or split into focused sub-agents.`;

    try {
      dbExec(
        `INSERT INTO agent_lab_recommendations (type, category, target_agent, title, description, rationale, status, priority) VALUES ('proactive', 'skill-bloat', '${esc(r.agentId)}', 'Consider splitting ${r.agentId} — ${r.total} skills detected', '${esc(description)}', 'Agent ${r.agentId} exceeds bloat threshold of ${REC_THRESHOLD} with ${r.total} total items', 'pending', 2);`
      );
      created++;
      if (!quiet) console.log(`  Created recommendation for ${r.agentId} (${r.total} items)`);
    } catch (e) {
      if (!quiet) console.error(`  Error creating rec for ${r.agentId}: ${e.message}`);
    }
  }

  return created;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
  const isJson = process.argv.includes("--json");
  const isQuiet = process.argv.includes("--quiet");
  const isCompact = process.argv.includes("--compact");

  // Count items for all agents
  const results = CORE_AGENTS.map(countAgentItems);

  if (isJson) {
    console.log(JSON.stringify(results, null, 2));
    return;
  }

  // Generate and print report
  const report = generateReport(results);
  console.log(report);
  log(report);

  // Create recommendations for bloated agents
  if (!isQuiet) {
    console.log("");
    console.log("RECOMMENDATIONS:");
    const created = createRecommendations(results, false);
    console.log(`  Total new recommendations: ${created}`);
  }

  // --compact: trigger compaction for all bloated agents
  if (isCompact) {
    const bloated = results.filter((r) => r.total >= REC_THRESHOLD);
    if (bloated.length === 0) {
      console.log("\nCOMPACT: No agents over threshold — nothing to compact.");
    } else {
      console.log(`\nCOMPACT: Triggering compaction for ${bloated.length} bloated agents...`);
      const compactResults = [];
      for (const r of bloated) {
        const result = compactAgent(r.agentId, isQuiet);
        compactResults.push(result);
      }
      const ok = compactResults.filter((r) => r.status === "ok").length;
      const markers = compactResults.filter((r) => r.status === "marker").length;
      const errors = compactResults.filter((r) => r.status === "error").length;
      console.log(`\nCOMPACT SUMMARY: ${ok} compacted, ${markers} markers written, ${errors} errors`);
      log(`COMPACT: ${ok} compacted, ${markers} markers, ${errors} errors`);
    }
  }
}

// ---------------------------------------------------------------------------
// Compact a bloated agent session via openclaw CLI
// ---------------------------------------------------------------------------
function compactAgent(agentId, quiet = false) {
  const COMPACT_LOG = path.join(OPENCLAW, "logs/compaction-nightly.log");
  const ts = new Date().toISOString();
  fs.mkdirSync(path.dirname(COMPACT_LOG), { recursive: true });

  try {
    // Try openclaw CLI compact command
    const result = execSync(
      `export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH && openclaw sessions compact --agent ${agentId} 2>&1 || true`,
      { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"], timeout: 30000 }
    ).trim();
    const line = `${ts} | COMPACT | ${agentId} | OK | ${result.slice(0, 200)}`;
    fs.appendFileSync(COMPACT_LOG, line + "\n");
    if (!quiet) console.log(`  ✓ Compacted ${agentId}: ${result.slice(0, 80)}`);
    return { agentId, status: "ok", output: result };
  } catch (e) {
    // Fallback: write a compaction marker file that the agent can act on next session
    const markerDir = path.join(OPENCLAW, `workspace-${agentId}`);
    if (fs.existsSync(markerDir)) {
      const markerPath = path.join(markerDir, ".compact-requested");
      fs.writeFileSync(markerPath, JSON.stringify({
        requestedAt: ts,
        reason: `bloat-check detected context bloat (≥${REC_THRESHOLD} items)`,
        requestedBy: "bloat-check --compact",
      }, null, 2));
      const line = `${ts} | COMPACT_MARKER | ${agentId} | marker written | ${markerPath}`;
      fs.appendFileSync(COMPACT_LOG, line + "\n");
      if (!quiet) console.log(`  ⚑ Marked ${agentId} for compaction (CLI unavailable — marker written)`);
      return { agentId, status: "marker", markerPath };
    }
    const line = `${ts} | COMPACT_FAIL | ${agentId} | ERROR | ${e.message}`;
    fs.appendFileSync(COMPACT_LOG, line + "\n");
    if (!quiet) console.error(`  ✗ Compact failed for ${agentId}: ${e.message}`);
    return { agentId, status: "error", error: e.message };
  }
}

// Export for use in nightly pipeline
module.exports = { countAgentItems, generateReport, createRecommendations, compactAgent, CORE_AGENTS };

if (require.main === module) {
  main();
}
