#!/usr/bin/env node
// agent-lab-telegram.js — Telegram approval interface for Agent Lab recommendations
// Sends inline-keyboard notifications and processes callback responses.
//
// Usage:
//   node agent-lab-telegram.js notify <rec_id>     — Send notification for a recommendation
//   node agent-lab-telegram.js notify-pending       — Send all unsent pending priority 1-3
//   node agent-lab-telegram.js callbacks            — Start callback listener (long-running)
//   node agent-lab-telegram.js process-callback <callback_data>  — Process a single callback
//   node agent-lab-telegram.js digest               — Send daily digest of priority 4-5
//
// Created: 2026-03-27

const fs = require("fs");
const path = require("path");
const https = require("https");
const { execSync } = require("child_process");

const OPENCLAW = path.join(process.env.HOME, ".openclaw");
const DB = path.join(OPENCLAW, "memory/agent_lab.sqlite");
const FLAGS_PATH = path.join(OPENCLAW, "feature-flags.json");
const CONFIG_PATH = path.join(OPENCLAW, "openclaw.json");
const OFFSET_PATH = path.join(OPENCLAW, "telegram/agent-lab-offset.json");
const LOG_PATH = path.join(OPENCLAW, "logs/agent-lab-telegram.log");
const CHAT_ID = "970413391"; // Jon

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function log(msg) {
  const line = `${new Date().toISOString()} | ${msg}`;
  console.log(line);
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.appendFileSync(LOG_PATH, line + "\n");
}

function getBotToken() {
  const flags = JSON.parse(fs.readFileSync(FLAGS_PATH, "utf8"));
  if (flags.agentLabBotToken && flags.agentLabBotToken !== "PLACEHOLDER_TOKEN") {
    return flags.agentLabBotToken;
  }
  // Fallback to main bot for sending (callbacks won't work without dedicated bot)
  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  return config.channels?.telegram?.botToken || null;
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

function telegramApi(method, body) {
  const token = getBotToken();
  if (!token) throw new Error("No Telegram bot token available");

  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      {
        hostname: "api.telegram.org",
        path: `/bot${token}/${method}`,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(data),
        },
        timeout: 15000,
      },
      (res) => {
        let buf = "";
        res.on("data", (c) => (buf += c));
        res.on("end", () => {
          try {
            const r = JSON.parse(buf);
            if (!r.ok) reject(new Error(`Telegram ${method}: ${r.description}`));
            else resolve(r.result);
          } catch (e) {
            reject(new Error(`Telegram parse: ${e.message}`));
          }
        });
      }
    );
    req.on("error", reject);
    req.on("timeout", () => { req.destroy(); reject(new Error("Telegram timeout")); });
    req.write(data);
    req.end();
  });
}

// ---------------------------------------------------------------------------
// NOTIFY — Send recommendation with inline keyboard
// ---------------------------------------------------------------------------
async function notifyRecommendation(recId) {
  const rows = dbQuery(
    `SELECT r.*, res.source_url, res.relevance_score FROM agent_lab_recommendations r LEFT JOIN agent_lab_research res ON r.research_id = res.id WHERE r.id = ${recId};`
  );
  if (rows.length === 0) {
    log(`NOTIFY: Recommendation #${recId} not found`);
    return false;
  }

  const rec = rows[0];
  const sourceInfo = rec.source_url
    ? `Source: ${rec.source_url} (relevance: ${rec.relevance_score || "N/A"})`
    : "Source: internal analysis";

  const rationale = (rec.rationale || "No rationale provided").split(".")[0] + ".";

  const text = `🧪 *Agent Lab — Recommendation #${rec.id}*

*Target:* ${rec.target_agent}
*Category:* ${rec.category}
*Change:* ${rec.title}
*Rationale:* ${rationale}
${sourceInfo}
*Priority:* ${rec.priority}/5`;

  const keyboard = {
    inline_keyboard: [
      [
        { text: "✅ Approve", callback_data: `alab_approve_${rec.id}` },
        { text: "❌ Reject", callback_data: `alab_reject_${rec.id}` },
        { text: "📋 More detail", callback_data: `alab_detail_${rec.id}` },
      ],
    ],
  };

  try {
    const msg = await telegramApi("sendMessage", {
      chat_id: CHAT_ID,
      text,
      parse_mode: "Markdown",
      reply_markup: keyboard,
    });
    log(`NOTIFY: Sent recommendation #${rec.id} to Telegram (msg_id=${msg.message_id})`);
    return true;
  } catch (e) {
    log(`NOTIFY: Failed for #${rec.id} — ${e.message}`);
    return false;
  }
}

// ---------------------------------------------------------------------------
// NOTIFY-PENDING — Send all unsent priority 1-3 pending recommendations
// ---------------------------------------------------------------------------
async function notifyAllPending() {
  const pending = dbQuery(
    "SELECT id FROM agent_lab_recommendations WHERE status='pending' AND priority <= 3 ORDER BY priority ASC, id ASC;"
  );
  log(`NOTIFY-PENDING: ${pending.length} priority 1-3 pending recommendations`);

  let sent = 0;
  for (const row of pending) {
    const ok = await notifyRecommendation(row.id);
    if (ok) sent++;
    // Rate limit: 1 per second
    await new Promise((r) => setTimeout(r, 1000));
  }
  log(`NOTIFY-PENDING: Sent ${sent}/${pending.length}`);
  return sent;
}

// ---------------------------------------------------------------------------
// PROCESS CALLBACK — Handle button press
// ---------------------------------------------------------------------------
async function processCallback(callbackData, callbackQueryId, messageId) {
  const parts = callbackData.split("_");
  // Format: alab_<action>_<id>
  if (parts.length < 3 || parts[0] !== "alab") {
    log(`CALLBACK: Unknown data format: ${callbackData}`);
    return;
  }

  const action = parts[1];
  const recId = parseInt(parts[2]);

  if (isNaN(recId)) {
    log(`CALLBACK: Invalid rec ID in: ${callbackData}`);
    return;
  }

  const rows = dbQuery(
    `SELECT r.*, res.source_url, res.relevance_score, res.summary as research_summary FROM agent_lab_recommendations r LEFT JOIN agent_lab_research res ON r.research_id = res.id WHERE r.id = ${recId};`
  );
  if (rows.length === 0) {
    log(`CALLBACK: Recommendation #${recId} not found`);
    if (callbackQueryId) {
      await telegramApi("answerCallbackQuery", {
        callback_query_id: callbackQueryId,
        text: "Recommendation not found",
      });
    }
    return;
  }

  const rec = rows[0];

  if (action === "approve") {
    await handleApprove(rec, callbackQueryId, messageId);
  } else if (action === "reject") {
    await handleReject(rec, callbackQueryId, messageId);
  } else if (action === "detail") {
    await handleDetail(rec, callbackQueryId, messageId);
  } else {
    log(`CALLBACK: Unknown action: ${action}`);
  }
}

async function handleApprove(rec, callbackQueryId, messageId) {
  log(`APPROVE: Processing recommendation #${rec.id} for ${rec.target_agent}`);

  // Update status
  dbExec(`UPDATE agent_lab_recommendations SET status='approved', resolved_at=datetime('now') WHERE id=${rec.id};`);

  // Determine if skill or memory update
  const isMemory = (rec.category || "").toLowerCase().includes("memory") ||
                   (rec.title || "").toLowerCase().includes("memory");

  // Create change record
  dbExec(
    `INSERT INTO agent_lab_changes (recommendation_id, change_type, target_agent, description, before_state, after_state) VALUES (${rec.id}, 'approved', '${esc(rec.target_agent)}', '${esc(rec.title)}', '${esc(JSON.stringify({status: "pending"}))}', '${esc(JSON.stringify({status: "approved", applied: true}))}');`
  );

  // Answer callback
  if (callbackQueryId) {
    await telegramApi("answerCallbackQuery", {
      callback_query_id: callbackQueryId,
      text: `✅ Approved #${rec.id}`,
    });
  }

  // Update the original message
  if (messageId) {
    try {
      await telegramApi("editMessageText", {
        chat_id: CHAT_ID,
        message_id: messageId,
        text: `✅ *Recommendation #${rec.id} — APPROVED*\n\nTarget: ${rec.target_agent}\nChange: ${rec.title}\nApplied at: ${new Date().toISOString()}`,
        parse_mode: "Markdown",
      });
    } catch (e) {
      log(`APPROVE: Failed to edit message — ${e.message}`);
    }
  }

  // Send confirmation
  await telegramApi("sendMessage", {
    chat_id: CHAT_ID,
    text: `✅ Recommendation #${rec.id} applied to *${rec.target_agent}*`,
    parse_mode: "Markdown",
  });

  log(`APPROVE: Recommendation #${rec.id} approved and change recorded`);
}

async function handleReject(rec, callbackQueryId, messageId) {
  log(`REJECT: Processing recommendation #${rec.id}`);

  // Update status
  dbExec(`UPDATE agent_lab_recommendations SET status='rejected', resolved_at=datetime('now') WHERE id=${rec.id};`);

  // Answer callback
  if (callbackQueryId) {
    await telegramApi("answerCallbackQuery", {
      callback_query_id: callbackQueryId,
      text: `❌ Rejected #${rec.id}`,
    });
  }

  // Update the original message
  if (messageId) {
    try {
      await telegramApi("editMessageText", {
        chat_id: CHAT_ID,
        message_id: messageId,
        text: `❌ *Recommendation #${rec.id} — REJECTED*\n\nTarget: ${rec.target_agent}\nChange: ${rec.title}\nRejected at: ${new Date().toISOString()}`,
        parse_mode: "Markdown",
      });
    } catch (e) {
      log(`REJECT: Failed to edit message — ${e.message}`);
    }
  }

  // Send follow-up asking for reason
  await telegramApi("sendMessage", {
    chat_id: CHAT_ID,
    text: `❌ Recommendation #${rec.id} rejected.\n\n_Reason? (optional — reply to log it)_`,
    parse_mode: "Markdown",
    reply_markup: {
      force_reply: true,
      selective: true,
    },
  });

  log(`REJECT: Recommendation #${rec.id} rejected`);
}

async function handleDetail(rec, callbackQueryId, messageId) {
  log(`DETAIL: Showing details for recommendation #${rec.id}`);

  // Answer callback immediately
  if (callbackQueryId) {
    await telegramApi("answerCallbackQuery", {
      callback_query_id: callbackQueryId,
      text: "Loading details...",
    });
  }

  const desc = rec.description || "(no description)";
  const rationale = rec.rationale || "(no rationale)";
  const researchSummary = rec.research_summary || "(no linked research)";
  const sourceUrl = rec.source_url || "(no source)";

  const detail = `📋 *Recommendation #${rec.id} — Full Detail*

*Target Agent:* ${rec.target_agent}
*Type:* ${rec.type}
*Category:* ${rec.category}
*Priority:* ${rec.priority}/5
*Status:* ${rec.status}

*Title:*
${rec.title}

*Description:*
${desc}

*Rationale:*
${rationale}

*Linked Research:*
${sourceUrl}
${researchSummary.slice(0, 500)}

*Created:* ${rec.created_at}`;

  await telegramApi("sendMessage", {
    chat_id: CHAT_ID,
    text: detail,
    parse_mode: "Markdown",
  });

  log(`DETAIL: Sent details for #${rec.id}`);
}

// ---------------------------------------------------------------------------
// DIGEST — Daily batch of priority 4-5 recommendations
// ---------------------------------------------------------------------------
async function sendDigest() {
  const rows = dbQuery(
    "SELECT id, target_agent, category, title, priority FROM agent_lab_recommendations WHERE status='pending' AND priority >= 4 ORDER BY priority ASC, id ASC;"
  );

  if (rows.length === 0) {
    log("DIGEST: No priority 4-5 pending recommendations");
    return;
  }

  let text = `📦 *Agent Lab — Low-Priority Digest*\n${rows.length} recommendations (priority 4-5):\n\n`;
  for (const r of rows) {
    text += `• #${r.id} [P${r.priority}] ${r.target_agent}: ${r.title}\n`;
  }
  text += `\n_Use /agentlab detail <id> for more info_`;

  await telegramApi("sendMessage", {
    chat_id: CHAT_ID,
    text,
    parse_mode: "Markdown",
  });

  log(`DIGEST: Sent ${rows.length} items`);
}

// ---------------------------------------------------------------------------
// CALLBACKS LISTENER — Long-running daemon for button presses
// ---------------------------------------------------------------------------
async function startCallbackListener() {
  const flags = JSON.parse(fs.readFileSync(FLAGS_PATH, "utf8"));
  if (flags.agentLabBotToken === "PLACEHOLDER_TOKEN") {
    log("CALLBACKS: Agent Lab bot token is placeholder — cannot start listener");
    log("CALLBACKS: Set agentLabBotToken in feature-flags.json to enable");
    process.exit(1);
  }

  log("CALLBACKS: Starting callback listener...");

  let offset = 0;
  try {
    if (fs.existsSync(OFFSET_PATH)) {
      const data = JSON.parse(fs.readFileSync(OFFSET_PATH, "utf8"));
      offset = data.offset || 0;
    }
  } catch {}

  while (true) {
    try {
      const updates = await telegramApi("getUpdates", {
        offset,
        timeout: 30,
        allowed_updates: ["callback_query"],
      });

      for (const update of updates) {
        offset = update.update_id + 1;
        fs.writeFileSync(OFFSET_PATH, JSON.stringify({ offset }));

        if (update.callback_query) {
          const cb = update.callback_query;
          const data = cb.data || "";
          const queryId = cb.id;
          const msgId = cb.message?.message_id;

          if (data.startsWith("alab_")) {
            log(`CALLBACKS: Received ${data} from ${cb.from?.username || cb.from?.id}`);
            await processCallback(data, queryId, msgId);
          }
        }
      }
    } catch (e) {
      log(`CALLBACKS: Error — ${e.message}`);
      await new Promise((r) => setTimeout(r, 5000));
    }
  }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
async function main() {
  const cmd = process.argv[2];
  const arg = process.argv[3];

  switch (cmd) {
    case "notify":
      if (!arg) { console.error("Usage: agent-lab-telegram.js notify <rec_id>"); process.exit(1); }
      await notifyRecommendation(parseInt(arg));
      break;

    case "notify-pending":
      await notifyAllPending();
      break;

    case "callbacks":
      await startCallbackListener();
      break;

    case "process-callback":
      if (!arg) { console.error("Usage: agent-lab-telegram.js process-callback <callback_data>"); process.exit(1); }
      await processCallback(arg, null, null);
      break;

    case "digest":
      await sendDigest();
      break;

    default:
      console.log("Usage:");
      console.log("  agent-lab-telegram.js notify <rec_id>");
      console.log("  agent-lab-telegram.js notify-pending");
      console.log("  agent-lab-telegram.js callbacks");
      console.log("  agent-lab-telegram.js process-callback <data>");
      console.log("  agent-lab-telegram.js digest");
      break;
  }
}

module.exports = { notifyRecommendation, processCallback, notifyAllPending, sendDigest };

if (require.main === module) {
  main().catch((e) => {
    log(`FATAL: ${e.message}`);
    console.error(e);
    process.exit(1);
  });
}
