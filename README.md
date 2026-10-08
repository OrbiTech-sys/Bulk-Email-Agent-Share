# n8n AI Bulk Email Agent (Claude + Gmail SMTP)

Excel upload → validation → Claude writes each email → **human review** → throttled Gmail SMTP send → audit log + report.
Built from `n8n_ai_bulk_email_agent_guide.docx`.

## Project layout
```
start-n8n.bat / start-n8n.sh  start n8n installed via npm (sets env vars)
docker-compose.yml            optional Docker alternative
workflows/
  bulk_email_agent.json       IMPORT THIS (main workflow)
  unsubscribe_webhook.json    IMPORT THIS TOO (opt-out endpoint)
  code/*.js                   source of every Code node (edit here)
  build_workflow.py           regenerates the two JSON files from code/*.js
scripts/                      make_sample_leads.py, validate_leads.py, test_smtp.py
sample/leads_sample.xlsx      example input with deliberate bad rows
data/files/
  prompts/system_prompt.txt   the AI instruction (edit freely, no re-import needed)
  reviews/  reports/  logs/   outputs, visible in VS Code
  suppression.csv             unsubscribed addresses
```

## 1. Setup in VS Code

### Option A: npm, no Docker (recommended on Windows)
1. Install Node.js 22 LTS from nodejs.org (n8n supports Node 20.19 to 24.x). Check: `node -v` and `npm -v`.
2. Install n8n: `npm install -g n8n@2`
3. Open this folder in VS Code, then start n8n with **Terminal > Run Task > "1a. Start n8n (npm, no Docker)"**, or run `start-n8n.bat` (Windows) / `./start-n8n.sh` (macOS/Linux). Do not run plain `n8n start`: the start script sets the data folder and the environment variables this project needs (`BULK_EMAIL_DATA_DIR`, `NODE_FUNCTION_ALLOW_BUILTIN=fs,path`, `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`, `N8N_RESTRICT_FILE_ACCESS_TO`).
4. Open http://localhost:5678 and create the owner account. Keep the terminal open; Ctrl+C stops n8n. Your computer must stay on for workflows to run.

### Option B: Docker
Run task **"1b. Start n8n (Docker alternative)"** (or `docker compose up -d`). On Linux also run `chmod -R a+rwX data/files`.

### Then, for both options
1. Edit the five constants at the top of `workflows/code/config.js` (sender name/email, reply-to, unsubscribe base URL, model), then run `python workflows/build_workflow.py`.
2. In n8n: **Workflows > Import from file**, and import both JSON files from `workflows/`.

## 2. Credentials (inside n8n only, never in Excel or JSON)
**Anthropic** – Credentials → *Header Auth*: Name `x-api-key`, Value = your Anthropic API key. Name it `Anthropic API Key`, then select it on the **Claude Generate Email** node.

**Gmail SMTP** – Credentials → *SMTP*, then select it on **Send Email (Gmail SMTP)**:

| Field | Value |
|---|---|
| Host | `smtp.gmail.com` |
| Port / SSL | **465 with SSL/TLS ON**, or **587 with SSL/TLS OFF** (STARTTLS is negotiated automatically) |
| User | your Gmail / Workspace address (must equal `SENDER_EMAIL`) |
| Password | a **Google App Password** (Google Account → Security → 2-Step Verification → App passwords) |

SMTP is for *sending*. IMAP/POP3 are for *reading* mail and are not needed to send (they only matter later if you add reply/bounce reading). Verify the login first with **"3. Test SMTP"** (`python scripts/test_smtp.py --send` after copying `.env.example` to `.env`).

## 3. Run a campaign
1. Validate your file: task **"4. Validate leads file"**. Data goes on the first sheet, named `Leads`; headers per the guide.
2. Open the **AI Bulk Email Agent** workflow → *Execute workflow* (or Publish it and use the production form URL).
3. **Preview**: Mode = Preview, pick a Campaign Type, add a prompt/CTA/tone, upload the `.xlsx`. Nothing is sent. Output: `data/files/reviews/<campaign_id>_review.xlsx` and `data/files/reports/<campaign_id>_preview.json`.
4. **Review** the file: edit subject/body if needed, set `send_status` to `Approved`, and clear `risk_flags` once you have fixed what it flags (rows with flags never send).
5. **Send**: Mode = Send, same Campaign ID, upload the *reviewed* file. Start with **Dry Run = Yes**, then run again with **No**. Use Batch Size 1 and 30+ seconds between batches for real sends.
6. Results: `data/files/reports/<id>_send_*.json` and the full audit log `data/files/logs/send_log.jsonl`.

## 4. Unsubscribe
Activate **Unsubscribe Handler**. Every email carries `UNSUBSCRIBE_BASE?email=…` (or the row's `unsubscribe_url`); a click appends the address to `suppression.csv`, and every later run skips it. `localhost` links only work for you. For real recipients, expose n8n on a public HTTPS URL and set `UNSUBSCRIBE_BASE` and `WEBHOOK_URL` to it.

## 5. What is blocked (guide §8 test plan)
| Case | Result |
|---|---|
| invalid email | skipped, logged `invalid_email` |
| no / unknown consent | `compliance_block_no_consent` |
| duplicate email | only first row proceeds |
| unsubscribed | `suppressed_unsubscribed` |
| invalid AI JSON / failed API call | `Needs Review`, never sent |
| word count, subject length, missing unsubscribe, unsupported claim (%, "guarantee", "case study") | flagged in `risk_flags`, blocked until a human clears it |
| not Approved / already sent in this campaign | skipped (idempotency on `campaign_id + email`) |
| SMTP failure | logged `failed` with the error; re-run Send after fixing (sent rows are not repeated) |

## Troubleshooting
- *"Module 'fs' is disallowed"* or *"access to env vars denied"*: n8n was started without the project's variables. Start it with `start-n8n.bat` / `start-n8n.sh` (npm) or recreate the container (`docker compose up -d --force-recreate`). If you run n8n with *external* task runners, the allow-list must go in the runner's `n8n-task-runners.json`, not the container env; the default npm and Docker setups use the internal runner and do not need this.
- *"The file is not writable / not in allowed path"*: `N8N_RESTRICT_FILE_ACCESS_TO` must point at the project's `data/files` (the start script does this).
- *Auth failed (535)*: you used the normal password, or 2-Step Verification is off. Use an App Password.
- *Connection hangs*: port/security mismatch (465↔SSL on, 587↔SSL off) or network blocks SMTP.
- *Nothing happens when no rows pass validation*: check `data/files/logs/send_log.jsonl` for the reasons.

## Limits and next steps
Gmail caps daily sending and flags bulk patterns; check Google's current limits and keep to small batches. For growth, move to a transactional provider (SES, Postmark, Resend) with SPF/DKIM/DMARC, bounce handling and `List-Unsubscribe` headers (n8n's SMTP node cannot set custom headers). Post-MVP ideas from the guide: dashboard, database for contacts/suppression, bounce/reply classification, A/B tests.
