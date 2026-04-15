# FlowHunt audit procedure

This is the procedure you (the agent) follow when the user says "flowhunt audit" or equivalent. Goal: produce `~/.flowhunt/audits/YYYY-MM-DD.md` with a focused automation report based on real data.

## Step 0 — precheck

1. Run `scripts/aw-check.sh`. If it is not `OK`, stop and run `setup.md` Step 1 instead. Do not try to audit without ActivityWatch.
2. Run `scripts/detect-agent.sh`. Store the result — connector branching in Step 2 depends on it.
3. Check `ls ~/.flowhunt/audits/` and note the date of the most recent audit if any. If the most recent is less than 24 hours old, warn the user: "Wczoraj/dzisiaj już robiliśmy audit. Chcesz nadpisać, czy przerwać?"
4. Check how many days of ActivityWatch data exist by looking at the bucket creation date:
   ```bash
   curl -fsS http://localhost:5600/api/0/buckets/ | jq -r '.[] | select(.id | startswith("aw-watcher-window")) | .created'
   ```
   If less than 7 days, tell the user the audit will be thin and ask whether to continue or wait.

## Step 1 — collect ActivityWatch data

Run `scripts/aw-query.sh 30`. Capture the JSON (top 100 `{app, title, seconds}` records). Pipe into your working memory or save to a temp file — you will reference this data while writing the audit.

Derive a few quick aggregates for your own understanding (do NOT include these in the output unless they support a specific recommendation):

- Total active hours across the period
- Top 10 apps by total time
- Top 10 window titles by total time
- How many distinct domains / page titles you see inside browser apps

These aggregates are context for pattern detection, not content.

## Step 2 — collect messaging / workspace data

You know which agent you are running inside. Probe for available MCP tools and call the ones that exist. Do NOT prompt the user to set up missing ones now — that's setup's job, not audit's job. If a connector is missing, note it as "unconnected" and proceed.

### Gmail (if available)

- Claude Code / Desktop: call `mcp__claude_ai_Gmail__gmail_search_messages` with query `newer_than:30d` and max 500 results. Collect `{date, from, subject, snippet}`. Do not call `gmail_read_message` — metadata is enough.
- Gemini: use `/gmail/search` slash command or the Workspace extension tools with a 30-day window.
- Codex: use the Gmail app tool (`$Gmail` in composer) or whatever Codex exposed.
- OpenCode: call the IMAP MCP server tools installed during setup (typically `search_emails` with date range).
- If no Gmail tool is available: mark `gmail: unconnected` in the data bundle and continue.

### Google Calendar (if available)

Same branching. List events for the last 30 days. Collect `{date, title, duration_minutes, attendee_count, recurring}`.

### Slack (if available)

List channels the user is in, count messages sent by the user in the last 30 days per channel, and grab subject-line-ish previews (first 80 chars of the top 20 messages from the user). We care about which channels the user drives, not read receipts.

### Optional: iMessage / WhatsApp / Telegram / Discord

Only if the user connected them during setup. Collect message counts per contact/group, top 10 contacts by volume. No message bodies — metadata only. The audit is about volume and topic clusters, not surveillance.

## Step 3 — apply the audit prompt

Load `prompts/audit-system-prompt.md`. That prompt is the system instructions you give yourself. Read it carefully. It specifies the five sections: Patterns, Automation recommendations, Not worth automating, Estimated time saved, Summary. It also specifies the hard rules (focus only on automation, no productivity tips, max 2 sentences per bullet, etc.).

Your analysis input is the union of:

1. The ActivityWatch top-100 records from Step 1
2. Every messaging/workspace data bundle you successfully collected in Step 2
3. Any previous audit markdown in `~/.flowhunt/audits/` that is less than 30 days old — read it so you can note changes since last audit (optional but highly valuable)

You do the analysis yourself. Do not call any external LLM API. Whatever model the user is running you with is the LLM that produces the output.

## Step 4 — write the output file

Create `~/.flowhunt/audits/YYYY-MM-DD.md` using the structure defined in `reference/audit-output-schema.md`. Use today's date. If a file already exists for today, overwrite it (Step 0 already confirmed with the user).

Follow the schema exactly. It specifies section order, heading levels, frontmatter, and the "data sources used" footer that lets the next audit know what was available this run.

## Step 5 — present top findings inline

After writing the file, print a compact summary in the chat:

```
Audit gotowy — zapisane do ~/.flowhunt/audits/2026-04-15.md

Top 3 do zautomatyzowania:
1. <first recommendation — one sentence what + one sentence how>
2. <second recommendation>
3. <third recommendation>

Estimated time saved: <the short string from section 4>

Chcesz żebym rozwinął którąkolwiek, albo zobaczyć pełny raport?
```

Do NOT paste the whole audit in chat. The file is the artifact; chat is the teaser.

## Step 6 — offer next actions

Finish by offering two concrete next moves:

- "Chcesz żebym zbudował pierwszą rekomendację? Mogę odpalić osobną sesję pracy nad tym."
- "Chcesz żebym porównał ten audit z poprzednim i pokazał co się zmieniło?"

The user can decline both and just close the session — that's fine. But asking keeps the loop going from "audit report" to "actual automation built".

## Rules specific to audit

1. **Thin data warning.** If less than 7 days of ActivityWatch or less than 20 emails / 20 calendar events, you MUST say so in the Summary section of the output file and recommend re-running after more data accrues.
2. **Never invent data.** If a source is unconnected, it's unconnected. Do not make up "looks like you send a lot of emails" when you have no email access.
3. **Respect the user's written ideas.** If the user mentioned anything in the chat before running the audit (e.g. "handlowcy spędzają 2h dziennie na szukaniu ofert"), that's the #1 priority input — surface it in section 2 before anything you detected from raw data.
4. **Language match.** Write the audit in the user's language. If they talked to you in Polish, the file is in Polish. If unclear, default to English.
5. **No API keys, no provider switching.** You are the LLM. Do not try to call Anthropic/OpenAI/Ollama. The user's existing agent session produces the output.
