# VAULT Protocol — How ATLAS manages it
# ~/.openclaw/agents/atlas/vault.md
 
## INTAKE — When Jon or human team drops anything
 
Step 1: RECEIVE
  Any message containing: a file, a link, "here is", "store this",
  "save this", "for the vault", "you'll need this" → triggers intake
 
Step 2: CLASSIFY (ATLAS decides automatically)
  What company does this relate to? [AP / BT / 1X / BSQ / HOLDCO / ALL]
  What category? [legal / finance / product / operations / marketing /
                  compliance / intel / template]
  What is the document? [write a one-line description]
  Who will need this? [which agents are likely to need this]
 
Step 3: FILE
  Save to correct vault/[company]/[category]/ path
  Filename format: [YYYY-MM-DD]_[company]_[description].[ext]
  Example: 2026-03-15_ap_series-a-nda-template.pdf
 
Step 4: UPDATE INDEX
  Append to vault/index.md:
  [DATE] | [COMPANY] | [CATEGORY] | [FILENAME] | [DESCRIPTION] | [RELEVANT AGENTS]
 
Step 5: NOTIFY
  If an agent is currently working on a related task:
  "VAULT UPDATE: [filename] just filed under [category].
   Sending to you as it is relevant to your current task."
 
## RETRIEVAL — When an agent needs something
 
Any agent can request: "ATLAS, I need [document type] for [company]"
ATLAS searches index.md and responds within the session.
ATLAS also proactively sends relevant documents at task assignment.
 
## FORM-FILLING PROTOCOL
When any form, application, NDA, or DD checklist needs to be completed:
  1. ATLAS retrieves the relevant template from VAULT/templates/
  2. ATLAS retrieves all relevant company data from VAULT/companies/
  3. ATLAS assigns to the appropriate agent:
     - Legal docs → HUNTER or NOVA-[company]
     - Financial forms → LEDGER
     - Regulatory applications → NOVA-[company] + RECON
     - Investor DD → HUNTER + APEX
  4. Agent completes using only verified VAULT data — no hallucination
  5. Completed form reviewed by ATLAS → ORION → Board before submission
  6. Filed back into VAULT once complete
 
## Jon Dump Protocol
Jon can drop anything at any time in any format:
  Voice note → ATLAS transcribes + categorises + files
  Screenshot → ATLAS reads + categorises + files
  Link → ATLAS fetches key information + files with source URL
  File → ATLAS categorises + files
  "Remember this: [X]" → ATLAS adds to relevant company/category
 
Jon never needs to organise anything.
ATLAS does it immediately and silently.
