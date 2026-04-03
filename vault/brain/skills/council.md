# The Council — Strategic Advisory Skill

## What It Is
The Council is Jon's 3-model advisory board for high-level brainstorming and strategic decisions. Three different AI models from three different labs, each bringing a distinct perspective.

## The Seats

| Seat | Agent | Model | Perspective |
|------|-------|-------|-------------|
| **Nova** | apex | Claude Opus 4.6 (Anthropic) | Strategic depth, nuanced reasoning, quality gate |
| **Sage** | council-sage | GPT-4.1 (OpenAI) | Pragmatic generalist, pattern matching, risk assessment |
| **Oracle** | council-oracle | Gemini 2.5 Pro (Google) | Systems thinking, first principles, analytical rigor |

## When to Convene
- Investment decisions or capital allocation
- New market entry strategy
- Product direction or pivot decisions
- Partnership or M&A evaluation
- Any decision where Jon wants multiple perspectives
- Brainstorming sessions on HoldCo strategy

## How to Activate
Jon says: **"Call the Council"** (or any variation: "convene the council", "council session", "I need the council")

## Council Session Protocol (for Jarvis)

When Jon calls The Council:

1. **Frame the question**: Take Jon's topic and create a clear, structured prompt
2. **Dispatch to all 3 members in parallel**:
   - Send to Nova (apex): the question + "Respond as Nova, Council member. Be direct."
   - Send to Sage (council-sage): the question + "Respond as Sage, Council member. Be direct."
   - Send to Oracle (council-oracle): the question + "Respond as Oracle, Council member. Be direct."
3. **Collect responses**: Wait for all 3
4. **Present to Jon**: Format as:

```
THE COUNCIL — [TOPIC]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧠 NOVA (Opus):
[Nova's perspective]
Confidence: X/10

⚡ SAGE (GPT-4.1):
[Sage's perspective]
Confidence: X/10

🔮 ORACLE (Gemini):
[Oracle's perspective]
Confidence: X/10

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONSENSUS: [where they agree]
DIVERGENCE: [where they disagree]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

5. **Discussion mode**: Jon may then engage with specific Council members or ask follow-ups. Route accordingly.

## Rules
- Council members must give INDEPENDENT opinions — no groupthink
- Disagreement is expected and valuable
- Each member ends with a confidence score (1-10)
- No member can see another's response before giving their own
- After initial opinions, Jon may ask them to debate each other

## Adding to Skill Index
Primary agents: Jarvis (orchestrator), Nova, Sage, Oracle
