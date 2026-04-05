# Content Drop Pipeline

## Owner: Nova (@Nova_voss_bot)

## When to Use
When Jon drops ANY content to Nova on Telegram: links, articles, PDFs, voice notes, ideas, research, competitor posts, or anything he wants turned into postable content.

## Channel Rules
- **Nova** = content drops, content creation, brand strategy, creative
- **Jarvis** = operations, admin, fleet, calendar, ClickUp
- **Cortex** = design, graphics, system config, deep work
- If Jon sends content to Jarvis, Jarvis redirects to Nova

## Pipeline

### Step 1: Nova Receives & Routes
1. Acknowledge: "On it. 5 ready-to-post pieces in 15 min."
2. Forward raw material to Scout for research extraction

### Step 2: Scout Researches (5 min)
1. Read/summarize the input (3-5 bullet points)
2. Research context: what's the broader conversation on LinkedIn/X?
3. Find Jon's angle: what unique take can he have given Biptap, 1TXO, BSQ?
4. Identify the emotional hook: what stops the scroll?
5. Write to: `/Users/apex/.openclaw/workspace-orion/memory/content-drop-research-[timestamp].md`

### Step 3: Echo Creates (10 min)
1. Read: Jon's voice profile + Scout's research + original source
2. Apply Anti-AI Content Rules (see below)
3. Create 5 pieces:
   - LinkedIn post (150-300 words, opinion-driven, bold hook)
   - X/Twitter thread (5-7 tweets, curiosity-driven)
   - X/Twitter hot take (single tweet, controversial, <280 chars)
   - IG Reel script (60s: hook → story → CTA + caption + hashtags)
   - IG carousel outline (7 slides with text per slide)

### Step 4: Nova Quality Gates (3 min)
1. Does it sound like Jon or like AI?
2. No banned AI words
3. Hook is fresh (check content-used-hooks.md)
4. Specific details present, not vague platitudes
5. Rewrite anything weak — don't send back to Echo

### Step 5: Design (if needed) → Cortex
If carousels or graphics needed:
- Nova sends design brief to Cortex (Claude Code)
- Cortex creates via Canva MCP / Gamma / image tools
- Returns finished assets

### Step 6: Nova Delivers to Jon
- 5 pieces, copy-paste ready, labeled by platform
- Design assets linked from Google Drive if applicable
- Suggested posting times included

## Anti-AI Content Rules

### NEVER:
- Start with "In today's fast-paced world" or any generic opener
- Use: leverage, delve, landscape, realm, foster, navigate, holistic, synergy, cutting-edge
- Have perfectly balanced paragraph lengths
- Use three-point lists with parallel structure
- Sound like a LinkedIn influencer template
- End with "What do you think? Drop a comment below!"
- Use em dashes excessively

### MUST:
- Sound like a real person talking, not writing
- Have uneven rhythm — some sentences short. Some longer and more complex.
- Include specific details (numbers, names, places, dates)
- Have Jon's actual opinions, not safe middle-ground takes
- Include imperfection — a casual aside, raw honesty
- Use Jon's vocabulary: bold claims, geopolitics meets fintech
- Feel like overhearing a conversation, not reading a press release
- Break grammar rules occasionally like a human would

## Tools Required
- Jon's voice profile: `/Users/apex/.openclaw/workspace-orion/memory/jon-voice-profile.md`
- Hook tracker: `/Users/apex/.openclaw/workspace-signal/content-used-hooks.md`
- Canva MCP (Cortex only): generate-design, export-design
- Gamma MCP (Cortex only): generate presentations
- Browser: for URL content extraction
