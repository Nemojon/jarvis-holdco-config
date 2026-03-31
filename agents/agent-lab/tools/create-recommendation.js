#!/usr/bin/env node
// create-recommendation.js — Writes to agent_lab_recommendations with status=pending
const { execSync } = require("child_process");
const path = require("path");

const DB = path.join(process.env.HOME, ".openclaw/memory/agent_lab.sqlite");
const CORE_AGENTS = [
  "apex", "atlas", "aurora", "cto", "hunter",
  "ledger", "main", "orion", "pastor-zion", "recon", "signal",
];

const jsonArg = process.argv[2];
if (!jsonArg) {
  console.error(
    'Usage: create-recommendation.js \'{"type","category","target_agent","title","description","rationale","research_id","priority"}\''
  );
  process.exit(1);
}

let rec;
try {
  rec = JSON.parse(jsonArg);
} catch (e) {
  console.error(`Invalid JSON: ${e.message}`);
  process.exit(1);
}

// Validate required fields
const required = ["type", "category", "target_agent", "title", "priority"];
for (const field of required) {
  if (!rec[field]) {
    console.error(`Missing required field: ${field}`);
    process.exit(1);
  }
}
if (!["reactive", "proactive"].includes(rec.type)) {
  console.error('type must be "reactive" or "proactive"');
  process.exit(1);
}
if (!CORE_AGENTS.includes(rec.target_agent)) {
  console.error(`Unknown agent: ${rec.target_agent}`);
  process.exit(1);
}
if (rec.priority < 1 || rec.priority > 5) {
  console.error("priority must be 1-5");
  process.exit(1);
}

const esc = (s) => (s ? String(s).replace(/'/g, "''") : "");
const sql = `INSERT INTO agent_lab_recommendations (type, category, target_agent, title, description, rationale, research_id, status, priority) VALUES ('${esc(rec.type)}', '${esc(rec.category)}', '${esc(rec.target_agent)}', '${esc(rec.title)}', '${esc(rec.description || "")}', '${esc(rec.rationale || "")}', ${rec.research_id || "NULL"}, 'pending', ${rec.priority}); SELECT last_insert_rowid();`;

try {
  const result = execSync(`sqlite3 "${DB}" "${sql}"`, {
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
  });
  const id = result.trim();
  console.log(JSON.stringify({ success: true, id: parseInt(id), status: "pending" }));
} catch (e) {
  console.error(`DB error: ${e.stderr?.toString() || e.message}`);
  process.exit(1);
}
