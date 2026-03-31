#!/usr/bin/env node
// get-agent-config.js — Reads full config for a named agent
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const OPENCLAW = path.join(process.env.HOME, ".openclaw");
const CONFIG = JSON.parse(fs.readFileSync(path.join(OPENCLAW, "openclaw.json"), "utf8"));

const CORE_AGENTS = [
  "apex", "atlas", "aurora", "cto", "hunter",
  "ledger", "main", "orion", "pastor-zion", "recon", "signal",
];

const agentId = process.argv[2];
if (!agentId) {
  console.error("Usage: get-agent-config.js <agent_id>");
  process.exit(1);
}
if (!CORE_AGENTS.includes(agentId)) {
  console.error(`Unknown agent: ${agentId}. Valid: ${CORE_AGENTS.join(", ")}`);
  process.exit(1);
}

const agentDir = path.join(OPENCLAW, "agents", agentId);
const entry = CONFIG.agents.list.find((a) => a.id === agentId);

// Read prompt files
const prompts = {};
for (const fname of ["CLAUDE.md", "identity.md", "soul.md"]) {
  const fpath = path.join(agentDir, fname);
  if (fs.existsSync(fpath)) {
    const content = fs.readFileSync(fpath, "utf8");
    prompts[fname] = {
      content,
      size: content.length,
      md5: crypto.createHash("md5").update(content).digest("hex"),
    };
  }
}

// Check for SOUL.md in agent/ subdir (aurora, recon, signal have these)
const agentSubSoul = path.join(agentDir, "agent", "SOUL.md");
if (fs.existsSync(agentSubSoul)) {
  const content = fs.readFileSync(agentSubSoul, "utf8");
  prompts["agent/SOUL.md"] = {
    content,
    size: content.length,
    md5: crypto.createHash("md5").update(content).digest("hex"),
  };
}

// Read models.json
let models = null;
const modelsPath = path.join(agentDir, "agent", "models.json");
if (fs.existsSync(modelsPath)) {
  models = JSON.parse(fs.readFileSync(modelsPath, "utf8"));
}

// Workspace CLAUDE.md
let workspacePrompt = null;
const workspaceClaude = path.join(OPENCLAW, `workspace-${agentId}`, "CLAUDE.md");
if (fs.existsSync(workspaceClaude)) {
  const content = fs.readFileSync(workspaceClaude, "utf8");
  workspacePrompt = {
    content,
    size: content.length,
    md5: crypto.createHash("md5").update(content).digest("hex"),
  };
}

// Compute version hash
const hash = crypto.createHash("md5");
for (const fname of ["CLAUDE.md", "identity.md", "soul.md"]) {
  if (prompts[fname]) hash.update(prompts[fname].content);
}
const versionHash = hash.digest("hex");

const result = {
  id: agentId,
  name: entry?.name || entry?.identity?.name || agentId,
  model: entry?.model || CONFIG.agents.defaults.model,
  subagents: entry?.subagents || null,
  version_hash: versionHash,
  system_prompt_files: prompts,
  workspace_prompt: workspacePrompt,
  models_config: models,
};

console.log(JSON.stringify(result, null, 2));
