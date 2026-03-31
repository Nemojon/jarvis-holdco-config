#!/usr/bin/env node
// apply-skill-update.js — Applies a skill change to target agent + creates audit record
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
    'Usage: apply-skill-update.js \'{"recommendation_id","change_type","target_agent","description","file","new_content"}\''
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

// Validate
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

// Determine target file
const targetFile = change.file;
if (!targetFile) {
  console.error("Missing 'file' field — the relative path within the agent dir to update");
  process.exit(1);
}
const fullPath = path.join(OPENCLAW, "agents", change.target_agent, targetFile);

// Capture before state
let beforeState = null;
if (fs.existsSync(fullPath)) {
  beforeState = fs.readFileSync(fullPath, "utf8");
}

// Apply the change
const afterState = change.new_content;
if (!afterState) {
  console.error("Missing 'new_content' field");
  process.exit(1);
}

// Backup before writing
const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
if (beforeState !== null) {
  fs.copyFileSync(fullPath, `${fullPath}.backup.${timestamp}`);
}

fs.mkdirSync(path.dirname(fullPath), { recursive: true });
fs.writeFileSync(fullPath, afterState, "utf8");

// Write audit record
const esc = (s) => (s ? String(s).replace(/'/g, "''") : "");
const beforeJson = JSON.stringify(beforeState);
const afterJson = JSON.stringify(afterState);
const sql = `INSERT INTO agent_lab_changes (recommendation_id, change_type, target_agent, description, before_state, after_state) VALUES (${change.recommendation_id || "NULL"}, '${esc(change.change_type)}', '${esc(change.target_agent)}', '${esc(change.description || "")}', '${esc(beforeJson)}', '${esc(afterJson)}');`;

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
    change_type: change.change_type,
    backup: beforeState !== null ? `${fullPath}.backup.${timestamp}` : null,
    had_before_state: beforeState !== null,
  })
);
