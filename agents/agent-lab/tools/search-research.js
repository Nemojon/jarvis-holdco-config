#!/usr/bin/env node
// search-research.js — Queries agent_lab_research by keyword or tag
const { execSync } = require("child_process");
const path = require("path");

const DB = path.join(process.env.HOME, ".openclaw/memory/agent_lab.sqlite");
const query = process.argv[2];

if (!query) {
  console.error("Usage: search-research.js <keyword_or_tag>");
  process.exit(1);
}

const escaped = query.replace(/'/g, "''");
const sql = `SELECT id, source_name, title, summary, relevance_score, tags, created_at FROM agent_lab_research WHERE title LIKE '%${escaped}%' OR summary LIKE '%${escaped}%' OR tags LIKE '%${escaped}%' OR source_name LIKE '%${escaped}%' ORDER BY relevance_score DESC LIMIT 20;`;

try {
  const result = execSync(`sqlite3 -json "${DB}" "${sql}"`, {
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
  });
  const rows = JSON.parse(result || "[]");
  console.log(JSON.stringify(rows, null, 2));
} catch (e) {
  const stderr = e.stderr?.toString() || "";
  if (stderr.includes("no such table")) {
    console.log("[]");
  } else {
    console.error(`Search error: ${stderr || e.message}`);
    process.exit(1);
  }
}
