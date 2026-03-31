#!/usr/bin/env node
// list-agents.js — Returns all 11 agent names, models, version hashes, timestamps
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const OPENCLAW = path.join(process.env.HOME, ".openclaw");
const CONFIG = JSON.parse(fs.readFileSync(path.join(OPENCLAW, "openclaw.json"), "utf8"));

const CORE_AGENTS = [
  "apex", "atlas", "aurora", "cto", "hunter",
  "ledger", "main", "orion", "pastor-zion", "recon", "signal",
];

const agents = [];

for (const id of CORE_AGENTS) {
  const entry = CONFIG.agents.list.find((a) => a.id === id);
  const agentDir = path.join(OPENCLAW, "agents", id);

  // Model from config
  const model = entry?.model?.primary || CONFIG.agents.defaults.model.primary || "unknown";

  // Version hash from version.json if it exists
  let versionHash = null;
  let lastModified = null;
  const versionPath = path.join(agentDir, "agent", "version.json");
  if (fs.existsSync(versionPath)) {
    try {
      const v = JSON.parse(fs.readFileSync(versionPath, "utf8"));
      versionHash = v.version_hash || null;
      lastModified = v.last_modified || null;
    } catch {}
  }

  // Fallback: compute hash from prompt files
  if (!versionHash) {
    const crypto = require("crypto");
    const hash = crypto.createHash("md5");
    for (const fname of ["CLAUDE.md", "identity.md", "soul.md"]) {
      const fpath = path.join(agentDir, fname);
      if (fs.existsSync(fpath)) {
        hash.update(fs.readFileSync(fpath, "utf8"));
      }
    }
    versionHash = hash.digest("hex");

    // Get last modified from most recent prompt file
    let latest = 0;
    for (const fname of ["CLAUDE.md", "identity.md", "soul.md"]) {
      const fpath = path.join(agentDir, fname);
      if (fs.existsSync(fpath)) {
        const mtime = fs.statSync(fpath).mtimeMs;
        if (mtime > latest) latest = mtime;
      }
    }
    lastModified = latest > 0 ? new Date(latest).toISOString() : null;
  }

  agents.push({
    id,
    name: entry?.name || entry?.identity?.name || id,
    model,
    version_hash: versionHash,
    last_modified: lastModified,
  });
}

console.log(JSON.stringify(agents, null, 2));
