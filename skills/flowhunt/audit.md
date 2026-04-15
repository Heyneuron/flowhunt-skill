# FlowHunt audit procedure

This is the procedure you (the agent) follow when the user says "flowhunt audit" or equivalent. Goal: produce `~/.flowhunt/audits/YYYY-MM-DD.md` with a focused automation report based on real data.

You have `bash`, `curl`, `jq`, and whatever MCP tools the user wired up during setup. No helper scripts. The facts you need are in `reference/activitywatch-api.md` (the curl + AQL recipe) and `reference/environment.md` (sandbox constraints per agent). You construct the commands yourself and adapt to what your environment allows.

## Step 0 — precheck

1. Verify ActivityWatch is running:

   ```bash
   curl -fsS --max-time 2 http://localhost:5600/api/0/info
   ```

   If it fails with connection refused, stop and run `setup.md` Step 2 instead. Do not try to audit without AW.

2. Detect which agent you are (same table as setup.md Step 0 and `reference/environment.md`): check `CODEX_THREAD_ID`, `CLAUDECODE`, `GEMINI_CLI`, `OPENCODE_CLIENT`. Store the result — per-agent connector probing in Step 2 depends on it.

3. Check for a previous audit:

   ```bash
   ls -1t ~/.flowhunt/audits/*.md 2>/dev/null | head -1
   ```

   If there's a file from less than 24 hours ago, warn the user: "Mamy już dzisiejszy audit, chcesz nadpisać?" If they decline, exit.

4. Check how many days of AW data you have:

   ```bash
   curl -fsS http://localhost:5600/api/0/buckets/ | jq -r '.[] | select(.id | startswith("aw-watcher-window")) | .created'
   ```

   Parse the timestamp, compute days since creation. If less than 7 days, tell the user: "Masz tylko N dni danych, audit będzie cienki. Chcesz mimo to, czy poczekać?" Proceed based on answer.

## Step 1 — collect ActivityWatch data

Read `reference/activitywatch-api.md` → section "The audit query". It gives you the exact AQL + POST payload for "top 100 app+title, AFK-filtered, last N days".

Construct the request yourself and capture the response. The skeleton:

```bash
START=$(date -u -v-30d +"%Y-%m-%dT00:00:00+00:00" 2>/dev/null || date -u -d "30 days ago" +"%Y-%m-%dT00:00:00+00:00")
END=$(date -u -v+1d +"%Y-%m-%dT00:00:00+00:00" 2>/dev/null || date -u -d "+1 day" +"%Y-%m-%dT00:00:00+00:00")

jq -nc \
  --arg period "${START}/${END}" \
  --arg query 'events = flood(query_bucket(find_bucket("aw-watcher-window_"))); not_afk = flood(query_bucket(find_bucket("aw-watcher-afk_"))); not_afk = filter_keyvals(not_afk, "status", ["not-afk"]); events = filter_period_intersect(events, not_afk); events = merge_events_by_keys(events, ["app", "title"]); RETURN = sort_by_duration(events);' \
  '{timeperiods: [$period], query: [$query]}' \
| curl -fsS -X POST -H "Content-Type: application/json" --data-binary @- http://localhost:5600/api/0/query/ \
| jq '.[0] | map(select(.duration >= 30)) | sort_by(-.duration) | .[0:100] | map({app: .data.app, title: (.data.title // ""), seconds: (.duration | floor)})'
```

Keep the resulting JSON in your working memory. This is your primary data source.

Derive a few quick aggregates for your own pattern detection — do NOT include raw numbers in the output file unless they support a specific recommendation:

- Total active hours across the period
- Top 10 apps by total time
- Top 10 window titles by total time
- Rough distinct-app count

These are context for pattern detection, not content.

## Step 2 — collect messaging / workspace data

Probe for available MCP tools and call the ones that exist. Do NOT prompt the user to set up missing ones now — that is setup's job. If a connector is missing, mark it `unconnected` in the data bundle and proceed.

### Gmail (if available)

- `claude-code` / Claude Desktop: call `mcp__claude_ai_Gmail__gmail_search_messages` with query `newer_than:30d` and `max_results=500`. Collect date, from, subject, snippet. **Do not call `gmail_read_message`** — metadata is enough.
- `codex`: the Gmail app exposes tools under its own namespace — inspect your available tool list for anything matching `Gmail` / `gmail_*` and call the search equivalent.
- `gemini`: run `/gmail/search newer_than:30d max_results:500` or call the Workspace extension's search tool.
- `opencode`: call the IMAP MCP server's search tool (name depends on which server, typically `search_emails` or `list_messages`).
- No Gmail tool available: mark `gmail: unconnected` and continue.

### Google Calendar (if available)

Same per-agent branching. List events for the last 30 days. Collect date, title, duration_minutes, attendee_count, recurring.

### Slack (if available)

List channels the user is a member of, count messages sent by the user in the last 30 days per channel, and grab first 80 chars of their top 20 messages for topic inference. No full message bodies, no DMs by default.

### Optional: iMessage / WhatsApp / Telegram / Discord

Only if the user connected them during setup. Metadata only: contact counts, top 10 contacts by volume, no bodies unless explicitly asked.

## Step 3 — apply the audit prompt

Load `prompts/audit-system-prompt.md`. That is your system instructions for this task — read carefully. It specifies:

- Five sections: Patterns, Automation recommendations, Not worth automating, Estimated time saved, Summary
- Hard rules: focus only on automation, no productivity tips, max two sentences per bullet, no browser-tabs / RAM observations
- Language match to the user
- User's written ideas (if any) = highest priority input

Your analysis input is the union of:

1. ActivityWatch top-100 records from Step 1
2. Every messaging/workspace bundle you successfully collected in Step 2
3. Any previous audit markdown in `~/.flowhunt/audits/` less than 30 days old — read it so you can note changes since last audit (optional but high value)

**Do the analysis yourself.** You are the LLM. Do not try to call an external API. Whatever model the user is running you with produces the output.

## Step 4 — write the output file

Create `~/.flowhunt/audits/YYYY-MM-DD.md` using the exact structure defined in `reference/audit-output-schema.md`. Use today's date. If a file already exists for today, overwrite it (Step 0 already confirmed with the user).

Follow the schema exactly. Frontmatter is mandatory — the next audit reads it to understand what data was available last time.

## Step 5 — present top findings inline

After writing the file, print a compact summary in the chat:

```
Audit gotowy — zapisane do ~/.flowhunt/audits/2026-04-15.md

Top 3 do zautomatyzowania:
1. <first recommendation — one sentence what + one sentence how>
2. <second recommendation>
3. <third recommendation>

Estimated time saved: <short string from section 4>

Chcesz żebym rozwinął którąkolwiek, albo zobaczyć pełny raport?
```

Do NOT paste the whole audit in chat. The file is the artifact; chat is the teaser.

## Step 6 — offer next actions

Close with two concrete next moves:

- "Chcesz żebym zbudował pierwszą rekomendację? Mogę otworzyć osobną sesję pracy nad tym."
- "Chcesz porównanie z poprzednim audytem?"

The user can decline both and close the session — fine. Asking keeps the loop going from report to actual automation built.

## Rules specific to audit

1. **Thin data warning.** Less than 7 days of AW data or less than 20 emails / 20 calendar events → say so in the Summary section and recommend re-running after more data accrues.
2. **Never invent data.** If a source is unconnected, it is unconnected. Do not guess.
3. **Respect user-written ideas.** Anything the user mentioned in chat before the audit is the #1 priority input — surface it in Recommendations section before anything you detected from raw data.
4. **Language match.** File is in the user's language. Default English when unclear.
5. **No API keys, no provider switching.** You are the LLM.
6. **Adapt to your sandbox.** If you are in `codex` and a particular data fetch fails due to sandbox denial (rare for curl to localhost, but possible for some MCP tools), mark that source as unavailable, note it in the audit frontmatter, and continue. Do not waste time fighting the sandbox — it is a permanent constraint.
