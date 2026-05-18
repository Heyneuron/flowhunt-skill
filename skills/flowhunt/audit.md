# FlowHunt audit procedure

This is the procedure you (the agent) follow when the user says "flowhunt audit" or equivalent. Goal: produce a dated audit folder under `~/.flowhunt/audits/YYYY-MM-DD/` containing a focused automation report PLUS the raw data the report was built from, so the user (or a different agent in a later session) can re-analyze without re-fetching.

You have `bash`, `curl`, `jq`, and whatever MCP tools the user wired up during setup. No helper scripts. The facts you need are in `reference/activitywatch-api.md` (the curl + AQL recipe) and `reference/environment.md` (sandbox constraints per agent). You construct the commands yourself and adapt to what your environment allows.

## Modular structure (since v1.1)

The audit is split into three focused modules. Read and follow each in order:

1. **`audit-precheck.md`** — Step 0 (ActivityWatch health check, agent detection, audit folder creation) and Step 0.5 (workflow context intake or reuse). Do this first.
2. **`audit-collect.md`** — Step 1 (ActivityWatch data) and Step 2 (Gmail, Calendar, Tasks, Slack, messaging collection + raw dumps + intake.json). Do this second.
3. **`audit-output.md`** — Step 3 (apply analysis prompt), Step 4 (write audit.md), Step 5 (present teaser), Step 6 (ask user for their ideas), Step 7 (feedback CTA), Step 8 (next actions). Do this last.

## Output layout

Every audit run writes to a per-date folder:

```
~/.flowhunt/audits/
  2026-04-15/
    audit.md                      # the human-readable report
    raw/
      activitywatch.json          # top-100 AFK-filtered query output
      gmail.json                  # pruned Gmail search response
      calendar.json               # Calendar events list
      slack.json                  # Slack data if collected
      tasks.json                  # Live tracker output (Linear, Notion, ...)
      notion_docs.json            # Notion pages/databases if Notion is task tracker
      tasks.md                    # Copy of ~/.flowhunt/tasks.md if manual mode
      user-proposed.md            # Raw user answers to "what would YOU automate?"
      intake.json                 # What the user answered during setup
```

**Always dump raw.** Never put collection data only in `/tmp` or only in working memory. The user may want to re-analyze with a different prompt tomorrow, or another agent in a later session may want context. If the raw is gone, the audit is a dead end.

Overwrite behavior: if `~/.flowhunt/audits/YYYY-MM-DD/` already exists, ask the user before overwriting (`audit-precheck.md` Step 0 Point 3 handles this).

## Global rules for the audit

1. **Thin data warning.** No ActivityWatch, less than 7 days of AW data, or less than 20 emails / 20 calendar events / 10 tasks → say so in the Summary section and recommend re-running after more data accrues. But never block the audit — always produce the best report you can with available data.
2. **Never invent data.** If a source is unconnected, it is unconnected. Do not guess.
3. **Respect user-written tasks and user-proposed automations.** These are the two highest-priority inputs. Surface them in Recommendations section before anything you only detected from raw telemetry.
4. **Always dump raw.** If a collection step succeeds, its output goes to `raw/<source>.json` in the audit folder before you move on. Do not rely on working memory as the only copy.
5. **Language match.** File is in the user's language. Default English when unclear.
6. **No API keys, no provider switching.** You are the LLM.
7. **Adapt to your sandbox.** If you are in `codex` with a restrictive sandbox (network blocked — see `reference/environment.md`), bail out early with the three-options message, do not attempt curl/MCP calls that will hang.
