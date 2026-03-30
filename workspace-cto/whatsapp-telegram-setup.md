# WhatsApp & Telegram Setup — HoldCo Agent Team
**Date:** 2026-03-19 | **Author:** Cipher (CTO)

---

## 1. TELEGRAM — Current Status ✅

**Existing bot:** Already configured and running
- Bot token: `8710384496:AAG1cWbSz0QXMp20WYwGh_8c5umtS_s8QMs`
- Bound to agent: **Orion (Jarvis)**
- Status: Running, polling mode, last inbound 1min ago
- Allowed users: Jon (970413391), 130902006, 1806224103

### Creating a Second Telegram Bot for Agent Outreach

**Cannot be automated** — BotFather requires an interactive Telegram chat session from Jon's account.

**Steps for Jon:**
1. Open Telegram → search `@BotFather` → Start
2. Send `/newbot`
3. Name: `Jarvis HoldCo` (or any display name)
4. Username: `JarvisHoldCo_bot` (must end in `_bot`, try variations if taken: `JarvisHoldCoBot`, `HoldCoJarvis_bot`)
5. BotFather will reply with the bot token — copy it
6. Send to Cipher or save to `~/workspace-cto/telegram-outreach-bot-token.txt`

**After getting the token, Cipher will:**
1. Add a second Telegram account in `openclaw.json` under `channels.telegram.accounts`
2. Bind it to a specific agent or outreach workflow
3. Restart the gateway

**Example config for second bot:**
```json
"channels": {
  "telegram": {
    "enabled": true,
    "accounts": {
      "default": {
        "botToken": "8710384496:AAG1cWbSz0QXMp20WYwGh_8c5umtS_s8QMs",
        "dmPolicy": "allowlist",
        "allowFrom": ["970413391", "130902006", "1806224103"]
      },
      "outreach": {
        "botToken": "<NEW_BOT_TOKEN_HERE>",
        "dmPolicy": "open",
        "allowFrom": ["*"]
      }
    }
  }
}
```

---

## 2. WHATSAPP — Setup In Progress 🔄

### What's Available
OpenClaw has **built-in WhatsApp support** via WhatsApp Web (Baileys library). No external API or Twilio needed.

### What Was Done
1. ✅ Added WhatsApp channel config to `openclaw.json`:
   - `dmPolicy: "allowlist"` with Jon's number (+6581008908)
   - `groupPolicy: "allowlist"` 
   - Read receipts enabled
   - Ack reaction (👀) enabled
2. ✅ Ran `openclaw channels login --channel whatsapp` — **QR code generated successfully**

### ⚠️ ACTION REQUIRED: Jon Must Scan QR Code

The QR code was generated but expired (they last ~60 seconds). Jon needs to:

1. Run this command on the Mac mini:
   ```bash
   openclaw channels login --channel whatsapp
   ```
2. Open WhatsApp on his phone → Settings → Linked Devices → Link a Device
3. Scan the QR code displayed in terminal
4. Wait for "Connected" confirmation
5. Restart the gateway:
   ```bash
   openclaw gateway restart
   ```

### WhatsApp Config Added to openclaw.json
```json
"whatsapp": {
  "enabled": true,
  "dmPolicy": "allowlist",
  "allowFrom": ["+6581008908"],
  "groupPolicy": "allowlist",
  "groupAllowFrom": ["+6581008908"],
  "sendReadReceipts": true,
  "ackReaction": {
    "emoji": "👀",
    "direct": true,
    "group": "mentions"
  }
}
```

### Previous WhatsApp QR (workspace-orion)
- File: `/Users/apex/.openclaw/workspace-orion/whatsapp-qr.png` 
- Date: Mar 18 18:15 (yesterday) — **expired, not usable**

---

## 3. SUMMARY

| Channel | Status | Action Needed |
|---------|--------|---------------|
| Telegram (existing) | ✅ Running | None |
| Telegram (outreach bot) | ⏳ Pending | Jon creates bot via @BotFather |
| WhatsApp | ⏳ Config ready | Jon scans QR via `openclaw channels login --channel whatsapp` |

---

## 4. POST-SETUP: Agent Binding for WhatsApp

Once WhatsApp is linked, add a binding in openclaw.json:
```json
"bindings": [
  {
    "agentId": "orion",
    "match": { "channel": "telegram", "accountId": "default" }
  },
  {
    "agentId": "orion",
    "match": { "channel": "whatsapp" }
  }
]
```

Then restart: `openclaw gateway restart`
