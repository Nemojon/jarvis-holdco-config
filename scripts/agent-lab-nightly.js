#!/usr/bin/env node
// agent-lab-nightly.js — Nightly research + recommendation pipeline for Agent Lab
// Created: 2026-03-27
// Runs at 22:00 WITA when agentLabCronEnabled=true, or manually anytime.

const fs = require("fs");
const path = require("path");
const https = require("https");
const http = require("http");
const { execSync } = require("child_process");
const crypto = require("crypto");

const OPENCLAW = path.join(process.env.HOME, ".openclaw");
const DB = path.join(OPENCLAW, "memory/agent_lab.sqlite");
const FLAGS_PATH = path.join(OPENCLAW, "feature-flags.json");
const ENV_PATH = path.join(OPENCLAW, ".env");
const CONFIG_PATH = path.join(OPENCLAW, "openclaw.json");
const LOG_PATH = path.join(OPENCLAW, "logs/agent-lab-nightly.log");

const CORE_AGENTS = [
  "apex", "atlas", "aurora", "cto", "hunter",
  "ledger", "main", "orion", "pastor-zion", "recon", "signal",
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function log(msg) {
  const line = `${new Date().toISOString()} | ${msg}`;
  console.log(line);
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.appendFileSync(LOG_PATH, line + "\n");
}

function loadFlags() {
  return JSON.parse(fs.readFileSync(FLAGS_PATH, "utf8"));
}

function loadOpenAIKey() {
  try {
    const env = fs.readFileSync(ENV_PATH, "utf8");
    const m = env.match(/^OPENAI_API_KEY=(.+)$/m);
    return m ? m[1].trim() : process.env.OPENAI_API_KEY;
  } catch {
    return process.env.OPENAI_API_KEY;
  }
}

function loadConfig() {
  return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
}

function fetchUrl(url, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith("https") ? https : http;
    const req = mod.get(url, { headers: { "User-Agent": "AgentLab/1.0" }, timeout: timeoutMs }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return fetchUrl(res.headers.location, timeoutMs).then(resolve).catch(reject);
      }
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => resolve(data));
    });
    req.on("error", reject);
    req.on("timeout", () => { req.destroy(); reject(new Error("timeout")); });
  });
}

function callLLM(messages, model = "gpt-4.1-mini", maxTokens = 500) {
  return new Promise((resolve, reject) => {
    const apiKey = loadOpenAIKey();
    if (!apiKey) return reject(new Error("No OPENAI_API_KEY"));

    const body = JSON.stringify({ model, messages, max_tokens: maxTokens, temperature: 0 });
    const req = https.request(
      {
        hostname: "api.openai.com",
        path: "/v1/chat/completions",
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
          "Content-Length": Buffer.byteLength(body),
        },
        timeout: 60000,
      },
      (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => {
          try {
            const parsed = JSON.parse(data);
            if (parsed.error) return reject(new Error(parsed.error.message));
            resolve({
              content: parsed.choices?.[0]?.message?.content || "",
              usage: parsed.usage || {},
            });
          } catch (e) {
            reject(new Error(`LLM parse: ${e.message}`));
          }
        });
      }
    );
    req.on("error", reject);
    req.on("timeout", () => { req.destroy(); reject(new Error("LLM timeout")); });
    req.write(body);
    req.end();
  });
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

function esc(s) {
  return s ? String(s).replace(/'/g, "''").replace(/\\/g, "\\\\") : "";
}

// ---------------------------------------------------------------------------
// STEP 1: SCRAPE — Parse RSS/Atom/HTML feeds
// ---------------------------------------------------------------------------
function parseRssItems(xml, sourceName) {
  const items = [];
  // RSS <item> or Atom <entry>
  const itemRegex = /<(?:item|entry)>([\s\S]*?)<\/(?:item|entry)>/gi;
  let match;
  while ((match = itemRegex.exec(xml)) !== null) {
    const block = match[1];
    const title = block.match(/<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/title>/s)?.[1]?.trim() || "";
    const link =
      block.match(/<link[^>]*href=["']([^"']+)["']/)?.[1] ||
      block.match(/<link[^>]*>(.*?)<\/link>/s)?.[1]?.trim() ||
      block.match(/<guid[^>]*>(https?[^<]+)<\/guid>/s)?.[1]?.trim() ||
      "";
    const desc =
      block.match(/<(?:description|summary|content)[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/(?:description|summary|content)>/)?.[1]?.trim() || "";
    const pubDate = block.match(/<(?:pubDate|published|updated)[^>]*>(.*?)<\/(?:pubDate|published|updated)>/)?.[1]?.trim() || "";

    if (title && link) {
      items.push({
        source_name: sourceName,
        source_url: link.replace(/&amp;/g, "&"),
        title: title.replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">"),
        summary: desc.replace(/<[^>]+>/g, "").slice(0, 500),
        pub_date: pubDate,
      });
    }
  }
  return items;
}

function parseGitHubCommits(json) {
  try {
    const commits = JSON.parse(json);
    if (!Array.isArray(commits)) return [];
    return commits.slice(0, 10).map((c) => ({
      source_name: "anthropic-cookbook",
      source_url: c.html_url || `https://github.com/anthropics/anthropic-cookbook/commit/${c.sha}`,
      title: (c.commit?.message || "").split("\n")[0].slice(0, 200),
      summary: (c.commit?.message || "").slice(0, 500),
      pub_date: c.commit?.author?.date || "",
    }));
  } catch {
    return [];
  }
}

function parseAnthropicNews(html) {
  const items = [];
  // Match blog post links and titles from the news page
  const regex = /<a[^>]*href=["'](\/research\/[^"']+|\/news\/[^"']+)["'][^>]*>[\s\S]*?<(?:h[23]|span)[^>]*>([\s\S]*?)<\/(?:h[23]|span)>/gi;
  let match;
  while ((match = regex.exec(html)) !== null) {
    const href = match[1];
    const title = match[2].replace(/<[^>]+>/g, "").trim();
    if (title && href) {
      items.push({
        source_name: "anthropic-news",
        source_url: `https://www.anthropic.com${href}`,
        title,
        summary: "",
      });
    }
  }
  // Fallback: simpler pattern
  if (items.length === 0) {
    const simpler = html.matchAll(/href=["'](https:\/\/www\.anthropic\.com\/(?:research|news)\/[^"']+)["'][^>]*>([^<]{5,})</g);
    for (const m of simpler) {
      items.push({
        source_name: "anthropic-news",
        source_url: m[1],
        title: m[2].trim(),
        summary: "",
      });
    }
  }
  return items.slice(0, 10);
}

async function scrapeAll() {
  const sources = [
    { url: "https://www.anthropic.com/news", parser: "anthropic", name: "anthropic-news" },
    { url: "https://api.github.com/repos/anthropics/anthropic-cookbook/commits?per_page=10", parser: "github", name: "anthropic-cookbook" },
    { url: "https://simonwillison.net/atom/everything/", parser: "rss", name: "simonwillison" },
    { url: "https://lilianweng.github.io/index.xml", parser: "rss", name: "lilianweng" },
    { url: "https://blog.langchain.dev/feed", parser: "rss", name: "langchain" },
    { url: "https://huggingface.co/papers.rss", parser: "rss", name: "huggingface-papers" },
  ];

  const allItems = [];
  for (const src of sources) {
    try {
      log(`SCRAPE: Fetching ${src.name} (${src.url})`);
      const raw = await fetchUrl(src.url);
      let items;
      if (src.parser === "github") items = parseGitHubCommits(raw);
      else if (src.parser === "anthropic") items = parseAnthropicNews(raw);
      else items = parseRssItems(raw, src.name);
      log(`SCRAPE: ${src.name} — ${items.length} items`);
      allItems.push(...items);
    } catch (e) {
      log(`SCRAPE: ${src.name} FAILED — ${e.message}`);
    }
  }
  return allItems;
}

// ---------------------------------------------------------------------------
// STEP 1b: DATE FILTER — skip items older than 30 days
// ---------------------------------------------------------------------------
function isItemFresh(item, maxAgeDays = 30) {
  // Check URL for stale year patterns (e.g. /2021/, /2022/)
  const currentYear = new Date().getFullYear();
  const urlYearMatch = item.source_url.match(/\/(20\d\d)\//); 
  if (urlYearMatch) {
    const urlYear = parseInt(urlYearMatch[1]);
    if (currentYear - urlYear > 0) {
      // More than a year old by URL heuristic
      return false;
    }
  }

  if (!item.pub_date) return true; // Can't determine age — allow through

  try {
    const parsed = new Date(item.pub_date);
    if (isNaN(parsed.getTime())) return true; // Unparseable date — allow through
    const ageMs = Date.now() - parsed.getTime();
    const ageDays = ageMs / (1000 * 60 * 60 * 24);
    return ageDays <= maxAgeDays;
  } catch {
    return true; // Parsing error — allow through
  }
}

function filterFresh(items) {
  const fresh = [];
  let stale = 0;
  for (const item of items) {
    if (isItemFresh(item)) {
      fresh.push(item);
    } else {
      log(`DATE_FILTER: Skipping stale item — "${item.title.slice(0, 60)}" (${item.pub_date || item.source_url})`);
      stale++;
    }
  }
  log(`DATE_FILTER: ${fresh.length} fresh, ${stale} stale items filtered out`);
  return fresh;
}

// ---------------------------------------------------------------------------
// STEP 2: DEDUP
// ---------------------------------------------------------------------------
function dedup(items) {
  const existing = dbQuery("SELECT source_url FROM agent_lab_research");
  const existingUrls = new Set(existing.map((r) => r.source_url));
  const seen = new Set();
  const fresh = [];
  for (const item of items) {
    if (!existingUrls.has(item.source_url) && !seen.has(item.source_url)) {
      seen.add(item.source_url);
      fresh.push(item);
    }
  }
  return fresh;
}

// ---------------------------------------------------------------------------
// STEP 3: SCORE
// ---------------------------------------------------------------------------
async function scoreItem(item) {
  const prompt = `Score this content 0.0-1.0 for relevance to an AI agent orchestration system managing 11 specialist agents. Scoring guide: 0.0-0.3 = general AI news, not applicable. 0.3-0.5 = somewhat relevant background. 0.5-0.8 = directly applicable techniques or patterns. 0.8-1.0 = specific, actionable improvements for multi-agent systems. Return only a JSON object: {"score": float, "reason": string}

Title: ${item.title}
Summary: ${item.summary || "(no summary)"}
Source: ${item.source_name}`;

  try {
    const { content } = await callLLM(
      [{ role: "user", content: prompt }],
      "gpt-4.1-mini",
      200
    );
    const cleaned = content.replace(/```json\n?/g, "").replace(/```/g, "").trim();
    const parsed = JSON.parse(cleaned);
    return {
      score: Math.max(0, Math.min(1, parseFloat(parsed.score) || 0)),
      reason: parsed.reason || "",
    };
  } catch (e) {
    log(`SCORE: Failed for "${item.title}" — ${e.message}`);
    return { score: 0, reason: `scoring error: ${e.message}` };
  }
}

// ---------------------------------------------------------------------------
// STEP 4: SAVE
// ---------------------------------------------------------------------------
function saveResearch(items) {
  let saved = 0;
  for (const item of items) {
    if (item.relevance_score <= 0.3) continue;
    try {
      const tags = item.source_name;
      dbExec(
        `INSERT OR IGNORE INTO agent_lab_research (source_url, source_name, title, summary, relevance_score, tags) VALUES ('${esc(item.source_url)}', '${esc(item.source_name)}', '${esc(item.title)}', '${esc(item.summary)}', ${item.relevance_score}, '${esc(tags)}');`
      );
      saved++;
    } catch (e) {
      log(`SAVE: Error — ${e.message}`);
    }
  }
  return saved;
}

// ---------------------------------------------------------------------------
// STEP 5: BLOAT CHECK
// ---------------------------------------------------------------------------
function bloatCheck() {
  const config = loadConfig();
  const flags = [];

  for (const agentId of CORE_AGENTS) {
    const agentDir = path.join(OPENCLAW, "agents", agentId);
    let toolCount = 0;

    // Count tools from workspace CLAUDE.md tool references
    const wsClaude = path.join(OPENCLAW, `workspace-${agentId}`, "CLAUDE.md");
    if (fs.existsSync(wsClaude)) {
      const content = fs.readFileSync(wsClaude, "utf8");
      // Count lines that look like tool/command definitions
      const toolLines = content.match(/^[-*]\s+.*(?:tool|command|script|node\s|exec\s)/gim);
      toolCount += toolLines ? toolLines.length : 0;
    }

    // Count CLAUDE.md sections as "skills"
    const claudeMd = path.join(agentDir, "CLAUDE.md");
    if (fs.existsSync(claudeMd)) {
      const content = fs.readFileSync(claudeMd, "utf8");
      const sections = content.match(/^##\s+/gm);
      toolCount += sections ? sections.length : 0;
    }

    log(`BLOAT: ${agentId} — ${toolCount} items`);
    if (toolCount >= 8) {
      flags.push({ agent: agentId, count: toolCount });
      try {
        dbExec(
          `INSERT INTO agent_lab_recommendations (type, category, target_agent, title, description, rationale, status, priority) VALUES ('proactive', 'bloat', '${agentId}', 'Bloat flag: ${toolCount} items in ${agentId}', '${agentId} has ${toolCount} tool/skill/section items — review for consolidation', 'Config bloat above threshold of 8', 'pending', 3);`
        );
      } catch (e) {
        log(`BLOAT: Recommendation write error — ${e.message}`);
      }
    }
  }
  return flags;
}

// ---------------------------------------------------------------------------
// STEP 6: RECOMMEND (for high-score items)
// ---------------------------------------------------------------------------
async function generateRecommendations(today) {
  const highScore = dbQuery(
    `SELECT id, title, summary, source_name, relevance_score FROM agent_lab_research WHERE relevance_score > 0.8 AND date(created_at) = '${today}';`
  );

  if (highScore.length === 0) {
    log("RECOMMEND: No items scored > 0.8 today");
    return 0;
  }

  // Load all agent configs (summaries only to keep prompt small)
  const agentSummaries = CORE_AGENTS.map((id) => {
    const claudeMd = path.join(OPENCLAW, "agents", id, "CLAUDE.md");
    let prompt = "";
    if (fs.existsSync(claudeMd)) {
      prompt = fs.readFileSync(claudeMd, "utf8").slice(0, 300);
    }
    const entry = loadConfig().agents.list.find((a) => a.id === id);
    return `${id} (${entry?.name || id}): ${prompt.split("\n").slice(0, 5).join(" ")}`;
  }).join("\n");

  let totalRecs = 0;

  for (const item of highScore) {
    const prompt = `Given this research finding:
Title: ${item.title}
Summary: ${item.summary}
Source: ${item.source_name}
Relevance: ${item.relevance_score}

And these agent configurations:
${agentSummaries}

Generate specific improvement recommendations. For each recommendation specify: target_agent, type (reactive/proactive), category, title, description, rationale. Return as a JSON array of objects.`;

    try {
      const { content } = await callLLM(
        [{ role: "system", content: "You are an AI agent improvement advisor. Return only valid JSON." },
         { role: "user", content: prompt }],
        "gpt-4.1-mini",
        1500
      );

      const cleaned = content.replace(/```json\n?/g, "").replace(/```/g, "").trim();
      const recs = JSON.parse(cleaned);
      if (!Array.isArray(recs)) continue;

      for (const rec of recs) {
        if (!CORE_AGENTS.includes(rec.target_agent)) continue;
        const type = ["reactive", "proactive"].includes(rec.type) ? rec.type : "proactive";
        try {
          dbExec(
            `INSERT INTO agent_lab_recommendations (type, category, target_agent, title, description, rationale, research_id, status, priority) VALUES ('${esc(type)}', '${esc(rec.category || "research")}', '${esc(rec.target_agent)}', '${esc(rec.title || "")}', '${esc(rec.description || "")}', '${esc(rec.rationale || "")}', ${item.id}, 'pending', ${Math.min(5, Math.max(1, parseInt(rec.priority) || 3))});`
          );
          totalRecs++;
        } catch (e) {
          log(`RECOMMEND: DB error — ${e.message}`);
        }
      }
    } catch (e) {
      log(`RECOMMEND: LLM error for "${item.title}" — ${e.message}`);
    }
  }

  return totalRecs;
}

// ---------------------------------------------------------------------------
// STEP 9: REPORT — Send to Telegram
// ---------------------------------------------------------------------------
function sendTelegramReport(report) {
  const config = loadConfig();
  const botToken = config.channels?.telegram?.botToken;
  const chatId = "970413391"; // Jon

  if (!botToken) {
    log("REPORT: No Telegram bot token — printing to console only");
    return;
  }

  return new Promise((resolve) => {
    const body = JSON.stringify({
      chat_id: chatId,
      text: report,
      parse_mode: "Markdown",
    });

    const req = https.request(
      {
        hostname: "api.telegram.org",
        path: `/bot${botToken}/sendMessage`,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => {
          try {
            const r = JSON.parse(data);
            if (r.ok) log("REPORT: Telegram sent OK");
            else log(`REPORT: Telegram error — ${r.description}`);
          } catch {}
          resolve();
        });
      }
    );
    req.on("error", (e) => { log(`REPORT: Telegram error — ${e.message}`); resolve(); });
    req.write(body);
    req.end();
  });
}

// ---------------------------------------------------------------------------
// MAIN PIPELINE
// ---------------------------------------------------------------------------
async function main() {
  const isManual = process.argv.includes("--manual");
  const flags = loadFlags();

  // Gate: if running from cron, check flag
  if (!isManual && !flags.agentLabCronEnabled) {
    log("GATE: agentLabCronEnabled=false and not --manual. Exiting.");
    process.exit(0);
  }

  const today = new Date().toISOString().slice(0, 10);
  log("=".repeat(60));
  log(`PIPELINE START — ${today} ${isManual ? "(manual)" : "(scheduled)"}`);

  // STEP 1: SCRAPE
  log("--- STEP 1: SCRAPE ---");
  const rawItems = await scrapeAll();
  log(`SCRAPE TOTAL: ${rawItems.length} items from all sources`);

  // STEP 1b: DATE FILTER
  log("--- STEP 1b: DATE FILTER ---");
  const datedItems = filterFresh(rawItems);

  // STEP 2: DEDUP
  log("--- STEP 2: DEDUP ---");
  const freshItems = dedup(datedItems);
  log(`DEDUP: ${freshItems.length} new items (${datedItems.length - freshItems.length} duplicates skipped)`);

  // STEP 3: SCORE
  log("--- STEP 3: SCORE ---");
  for (const item of freshItems) {
    const { score, reason } = await scoreItem(item);
    item.relevance_score = score;
    item.score_reason = reason;
    log(`SCORE: ${score.toFixed(2)} — "${item.title.slice(0, 60)}" — ${reason.slice(0, 80)}`);
  }
  const aboveThreshold = freshItems.filter((i) => i.relevance_score > 0.3);

  // STEP 4: SAVE
  log("--- STEP 4: SAVE ---");
  const saved = saveResearch(freshItems);
  log(`SAVE: ${saved} items saved (score > 0.3)`);

  // STEP 5: BLOAT CHECK
  log("--- STEP 5: BLOAT CHECK ---");
  const bloatFlags = bloatCheck();
  log(`BLOAT: ${bloatFlags.length} agents flagged`);

  // STEP 6: RECOMMEND
  log("--- STEP 6: RECOMMEND ---");
  const newRecs = await generateRecommendations(today);
  log(`RECOMMEND: ${newRecs} new recommendations created`);

  // STEP 7: AUTO-APPLY
  log("--- STEP 7: AUTO-APPLY ---");
  log("AUTO_APPLY_ENABLED=false, skipping auto-apply");

  // STEP 8: QUEUE
  log("--- STEP 8: QUEUE ---");
  const pendingCount = dbQuery(
    `SELECT COUNT(*) as cnt FROM agent_lab_recommendations WHERE status='pending' AND date(created_at) = '${today}';`
  )[0]?.cnt || 0;
  log(`QUEUE: ${pendingCount} pending recommendations from today`);

  // STEP 9: REPORT
  log("--- STEP 9: REPORT ---");
  const report = `🧪 *Agent Lab nightly report* — ${today}

Sources scraped: ${rawItems.length} raw → ${datedItems.length} after date filter
New items found: ${freshItems.length}
Items scored above 0.3: ${aboveThreshold.length}
Items saved to research DB: ${saved}
New recommendations queued: ${newRecs}
Bloat flags: ${bloatFlags.length > 0 ? bloatFlags.map((f) => `${f.agent}(${f.count})`).join(", ") : "none"}
Auto-apply: disabled`;

  log(`REPORT TEXT:\n${report}`);
  await sendTelegramReport(report);

  log("PIPELINE COMPLETE");
  log("=".repeat(60));
}

main().catch((e) => {
  log(`PIPELINE FATAL: ${e.message}`);
  console.error(e);
  process.exit(1);
});
