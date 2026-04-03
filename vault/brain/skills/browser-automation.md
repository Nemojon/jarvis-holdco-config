# Browser Automation

## When to Use
Any task requiring web interaction: LinkedIn monitoring, Gmail access, Google Calendar, regulatory portal checks, billing dashboard reads.

## Tools Required
- OpenClaw browser (Brave, profile: `openclaw`)
- Pre-authenticated logins: LinkedIn (jarvis@biptap.com), Gmail (jarvis@biptap.com + jon@biptap.com), Google Calendar (jarvis@biptap.com)

## Core Commands
- `openclaw browser navigate <url>` — load a page
- `openclaw browser snapshot --format aria` — extract page content as TEXT
- `openclaw browser click <ref>` — click element by reference
- `openclaw browser type <ref> "text"` — type into field
- `openclaw browser scroll` — scroll down
- `openclaw browser tabs` — list open tabs

## Step-by-Step
1. Navigate to target URL
2. Take snapshot with `--format aria` for text extraction
3. Parse the TEXT output for needed data
4. If interaction needed: click, type, scroll as required
5. Take another snapshot to verify result

## Known Pitfalls
- **NEVER send screenshots as output** — All output must be clean text (COR-001, repeated twice)
- Chrome/Brave must be running for snapshots — if down, fall back to API where available (LES-007)
- LinkedIn rate-limits browser sessions — space out requests, use Apify as fallback
- Some pages need scroll before content loads — take snapshot after scroll

## Output Rule
`snapshot --format aria` for text-based extraction. Report findings as structured text: key findings, data points, recommendations. One clean message. No images. No attachments.
