#!/usr/bin/env node
// apply-memory-update.js — Applies a memory update to target agent + creates audit record
// Same logic as apply-skill-update but specifically for workspace memory files
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const OPENCLAW = path.join(process.env.HOME, ".openclaw");
const DB = path.join(OPENCLAW, "memory/agent_lab.sqlite");
const FLAGS = JSON.parse(fs.readFileSync(path.join(OPENCLAW, "feature-flags.json"), "utf8"));

const CORE_AGENTS = [
  "apex", "atlas", "aurora", "cto", "hunter",
  "ledger", "main", "orion", "pastor-zion", "recon", "signal",
];

const jsonArg = process.argv[2];
if (!jsonArg) {
  console.error(
    'Usage: apply-memory-update.js \'{"recommendation_id","change_type","target_agent","description","section","content"}\''
  );
  process.exit(1);
}

let change;
try {
  change = JSON.parse(jsonArg);
} catch (e) {
  console.error(`Invalid JSON: ${e.message}`);
  process.exit(1);
}

if (!["auto", "approved"].includes(change.change_type)) {
  console.error('change_type must be "auto" or "approved"');
  process.exit(1);
}
if (!CORE_AGENTS.includes(change.target_agent)) {
  console.error(`Unknown agent: ${change.target_agent}`);
  process.exit(1);
}

// Feature flag gate
if (change.change_type === "auto" && !FLAGS.autoApplyEnabled) {
  console.error(
    "BLOCKED: AUTO_APPLY_ENABLED=false. Cannot apply auto changes. Set autoApplyEnabled=true in feature-flags.json or use change_type=approved."
  );
  process.exit(1);
}

// Target: workspace CLAUDE.md for the agent (memory lives here)
const workspaceDir = path.join(OPENCLAW, `workspace-${change.target_agent}`);
const targetFile = path.join(workspaceDir, "CLAUDE.md");

// Capture before state
let beforeState = null;
if (fs.existsSync(targetFile)) {
  beforeState = fs.readFileSync(targetFile, "utf8");
}

// Build new content — append section to workspace CLAUDE.md
const section = change.section || "AGENT LAB UPDATE";
const newBlock = `\n\n## ${section}\n${change.content}\n*— Added by Agent Lab on ${new Date().toISOString()}*\n`;

let afterState;
if (beforeState !== null) {
  afterState = beforeState + newBlock;
} else {
  afterState = `# ${change.target_agent} — Workspace Memory\n${newBlock}`;
}

// Backup before writing
const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
if (beforeState !== null) {
  fs.copyFileSync(targetFile, `${targetFile}.backup.${timestamp}`);
}

fs.mkdirSync(workspaceDir, { recursive: true });
fs.writeFileSync(targetFile, afterState, "utf8");

// Write audit record
const esc = (s) => (s ? String(s).replace(/'/g, "''") : "");
const beforeJson = JSON.stringify(beforeState);
const afterJson = JSON.stringify(afterState);
const sql = `INSERT INTO agent_lab_changes (recommendation_id, change_type, target_agent, description, before_state, after_state) VALUES (${change.recommendation_id || "NULL"}, '${esc(change.change_type)}', '${esc(change.target_agent)}', '${esc(change.description || "memory update: " + section)}', '${esc(beforeJson)}', '${esc(afterJson)}');`;

try {
  execSync(`sqlite3 "${DB}" "${sql}"`, { stdio: "pipe" });
} catch (e) {
  console.error(`DB audit error: ${e.stderr?.toString() || e.message}`);
}

console.log(
  JSON.stringify({
    success: true,
    target_agent: change.target_agent,
    file: targetFile,
    section,
    change_type: change.change_type,
    backup: beforeState !== null ? `${targetFile}.backup.${timestamp}` : null,
  })
);
