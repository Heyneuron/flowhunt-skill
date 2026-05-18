# FlowHunt audit — data collection

This module covers collecting raw data from all connected sources and dumping it to `~/.flowhunt/audits/YYYY-MM-DD/raw/`.

## Step 1 — collect ActivityWatch data (if available)

**Skip this step entirely if `aw_available = false`.** Write `{"unavailable": true, "reason": "ActivityWatch not running"}` to `raw/activitywatch.json` and proceed to Step 2.

If `aw_available = true`: Read `reference/activitywatch-api.md` → section "The audit query". It gives you the exact AQL + POST payload for "top 100 app+title, AFK-filtered, last N days".

Construct the request yourself and **save the raw response directly to `~/.flowhunt/audits/${TODAY}/raw/activitywatch.json`** — do not hold it only in working memory. Skeleton:

```bash
TODAY=$(date +%Y-%m-%d)
OUT=~/.flowhunt/audits/${TODAY}/raw
START=$(python3 -c "import datetime; print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=30)).strftime('%Y-%m-%dT00:00:00+00:00'))")
END=$(python3 -c "import datetime; print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=1)).strftime('%Y-%m-%dT00:00:00+00:00'))")

jq -nc \
  --arg period "${START}/${END}" \
  --arg query 'events = flood(query_bucket(find_bucket("aw-watcher-window_"))); not_afk = flood(query_bucket(find_bucket("aw-watcher-afk_"))); not_afk = filter_keyvals(not_afk, "status", ["not-afk"]); events = filter_period_intersect(events, not_afk); events = merge_events_by_keys(events, ["app", "title"]); RETURN = sort_by_duration(events);' \
  '{timeperiods: [$period], query: [$query]}' \
| curl -fsS -X POST -H "Content-Type: application/json" --data-binary @- http://localhost:5600/api/0/query/ \
| jq '.[0] | map(select(.duration >= 30)) | sort_by(-.duration) | .[0:100] | map({app: .data.app, title: (.data.title // ""), seconds: (.duration | floor)})' \
> ${OUT}/activitywatch.json
```

After the write, the raw file lives under `~/.flowhunt/audits/YYYY-MM-DD/raw/activitywatch.json`. Keep a copy in working memory too for the analysis step, but the source of truth is the file.

Derive a few quick aggregates for your own pattern detection — do NOT include raw numbers in the output file unless they support a specific recommendation:

- Total active hours across the period
- Top 10 apps by total time
- Top 10 window titles by total time
- Rough distinct-app count

## Step 2 — collect messaging / workspace / task data

For every connected source, collect AND **dump raw to `raw/<source>.json`** in the audit folder. If a source is unconnected, write `{"unconnected": true}` (or skip the file — your choice, be consistent).

### Gmail (if available)

- `claude-code` / Claude Desktop: call `mcp__claude_ai_Gmail__gmail_search_messages` with query `newer_than:30d` and `max_results=500`. Collect `date`, `from`, `subject`, `snippet` (the snippet is the first ~200 chars of the body, returned automatically by the search API — use it). For the top 20 emails by repeated sender or repeated subject pattern, you MAY additionally call `mcp__claude_ai_Gmail__gmail_read_message` to get full bodies — do this only when the pattern is interesting enough to justify the extra context tokens.
- `codex`: the Gmail app exposes tools under its own namespace — inspect your available tool list for anything matching `Gmail` / `gmail_*` and call the search equivalent.
- `gemini`: run `/gmail/search newer_than:30d max_results:500` or call the Workspace extension's search tool.
- `opencode`: call the IMAP MCP server's search tool (name depends on which server, typically `search_emails` or `list_messages`). IMAP returns envelopes by default; for the top 20 patterns, fetch the full body.
- No Gmail tool available: mark `gmail: unconnected` and continue.

**Dump the raw response (or a pruned version with just the fields you care about) to `raw/gmail.json` before moving on.**

**Content is the whole point.** Do not limit yourself to counts and sender names. "User sends a lot of emails" is useless. "User sends ~14 emails per week replying to pricing questions with nearly identical wording" is a recommendation. You need content to produce recommendations.

### Google Calendar (if available)

Same per-agent branching. List events for the last 30 days. Collect date, title, duration_minutes, attendee_count, recurring, description. If event descriptions are exposed by the tool, include them for the top 20 recurring events — that's where "weekly 1:1 where the same 3 topics always come up" patterns live.

**Dump to `raw/calendar.json`.**

### Task tracker (if available)

Based on `task_tracker` from intake, read `connectors/task-trackers.md` for the per-agent path. Branch:

- **Live tracker connector** (Linear / Notion / Jira / Asana / ClickUp / Todoist / Trello): call the tracker MCP to list open tasks assigned to the user, completed-in-last-30-days tasks, recurring tasks, and for the top 20 most-repeated patterns pull full descriptions. Dump to `raw/tasks.json`.
- **Manual mode** (`~/.flowhunt/tasks.md` exists from setup): read the file and treat its content as the task list. Copy it to `raw/tasks.md` in the audit folder (so the audit is self-contained even if the user later edits the central file).
- **Skipped or nothing available:** mark `tasks: unconnected` and continue without task signal.

**Task data is second-highest priority input after the user-proposed automations.** These are things the user explicitly identifies as work they care about — surface recommendations that target these tasks before anything you only inferred from AW.

> **Notion extended read:** If `task_tracker` is `notion` and the user did NOT opt out during setup, also collect recent Notion documents per `connectors/task-trackers.md` § "Notion as document source". Dump to `raw/notion_docs.json`.

### Slack (if available)

List the channels the user is a member of. For each channel, count the user's messages in the last 30 days, AND pull the **full content** of the user's top ~100 messages (sorted by recency), plus channel name and timestamp. For DMs, pull the user's most recent messages per conversation (top ~50 threads) with full content.

**Dump to `raw/slack.json`.**

Do not do metadata-only. Slack audits are only valuable when you can see what the user is actually saying.

Privacy note to communicate if user seems concerned: all data stays local, the agent reading it is the same agent they opened FlowHunt from, no FlowHunt cloud, no third-party telemetry. Users who opt out of content ingestion answer `no` to Slack in intake.

### Optional: iMessage / Telegram (bot) / Discord (bot)

Only if the user connected them during setup. Pull message counts per contact/group plus **content** for the top ~50 recent user-sent messages per channel. Do NOT ingest messages from other people in DMs without explicit permission — the user's own outbound messages are the main signal anyway.

**Dump to `raw/imessage.json` / `raw/telegram.json` / `raw/discord.json`.**

**WhatsApp is intentionally not supported.** If the user asks "can you also read WhatsApp?", explain that the only OSS path for personal accounts is `lharries/whatsapp-mcp` (whatsmeow-based), which carries a non-zero ban risk from Meta. We deliberately removed it from FlowHunt because losing a personal WhatsApp account costs more than an audit saves. They can experiment with it outside the skill if they want.

### Error handling during collection

If any tool call fails (timeout, auth error, rate limit, MCP server crash), follow this exact fallback:

1. **Retry once** after 3 seconds. Some MCP servers are slow to cold-start.
2. **If still failing:** write an error placeholder to `raw/<source>.json`:
   ```json
   {"error": "<source> collection failed", "reason": "<exact error message>", "timestamp": "2026-05-15T10:00:00+02:00"}
   ```
3. **Continue the audit.** Never abort the entire audit because one connector failed. The audit prompt is designed to work with partial data.
4. **Note the failure** in the `Data sources used this run` table with status `error:<short_reason>`.

**Rate limit safety:**
- Gmail: keep `max_results` at 500 or below. Do not make more than 3 search calls per audit.
- Slack: do not fetch more than 100 messages per channel. One `list_channels` + one `history` call per channel is enough.
- Task trackers: one `list_tasks` + one `list_projects` call. No per-task detail fetches unless the pattern is extremely interesting.

### Intake answers

Finally, write out what the user answered during setup (stored in your working memory during Step 1 of `setup.md`) as `raw/intake.json`. The `workflow_context` block is the single most important input for the audit.

```json
{
  "email": "gmail",
  "calendar": "google",
  "task_tracker": "linear",
  "slack": "yes",
  "optional_messaging": [],
  "agent": "claude-code",
  "language": "pl",
  "workflow_context": {
    "role": "CTO startupu B2B SaaS, ~10 osób w zespole",
    "time_drains": [
      "triage maila po nocach",
      "kopiowanie statusów ze Slacka do Linear co tydzień",
      "raport sprzedażowy w piątki — 6 tabelek na ręcznie"
    ],
    "failed_attempts": [
      "Zapier się rozsypał po update API HubSpota",
      "Notion AI halucynował w meeting notes"
    ],
    "sacred": [
      "1:1 z ludźmi nie ruszamy",
      "discovery calls robię sam"
    ],
    "goal": "oszczędzić 8h/tydz na operacjach i przerzucić to na product"
  }
}
```

This lets a future re-analysis understand both the technical setup AND the human context behind the data collection.

### Multi-account collection (optional, v1.1+)

If `~/.flowhunt/config.json` contains `connectors.additional_accounts` with entries where `connected = true`, collect from each additional account using the same per-agent branching as the primary account. For each additional account:

1. Determine the raw filename suffix: `<source>_<label>.json` (e.g. `gmail_służbowy.json`, `slack_klient_a.json`). If `label` is missing, use `secondary`.
2. Run the same collection logic as for the primary account (Gmail search, Slack history, etc.).
3. Dump to `raw/<source>_<label>.json`.
4. Note the account in the `Data sources used this run` table as `ok:<label>`.

If a secondary account fails, apply the same error handling (retry once, then error placeholder) — do not let a secondary account failure abort the audit.

**Example:** user has primary Gmail `user@gmail.com` + secondary `work@company.com`. After collecting `raw/gmail.json` from the primary, collect `raw/gmail_służbowy.json` from the secondary. Both feed into the same analysis.
