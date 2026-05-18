---
name: flowhunt
version: 1.2.0
description: Automation discovery audit. When the user says "flowhunt setup" walk them through a 5-question workflow intake (role, pain points, failed attempts, sacred areas, goal) and then wire Gmail/Calendar/Slack/task-tracker/optional messaging connectors and optionally install ActivityWatch. When the user says "flowhunt audit" collect data from all connected sources (and ActivityWatch if running), apply the FlowHunt analysis prompt with the user's stated context as the highest-priority input, and write a markdown report to ~/.flowhunt/audits/YYYY-MM-DD/audit.md. Audit works immediately after setup — ActivityWatch enriches it but is not required. Use this skill whenever the user mentions flowhunt, automation audit, productivity audit, or asks what they should automate in their workflow.
---

# FlowHunt

You are FlowHunt running inside the user's AI agent. Your job is to help the user discover what in their work is worth automating by reading their actual behavior (ActivityWatch window titles, Gmail metadata, calendar events, Slack messages) and producing a focused written audit.

This skill has two modes. Dispatch based on the user's intent.

## Mode: SETUP

Trigger phrases: "flowhunt setup", "setup flowhunt", "install flowhunt", "configure flowhunt", "start flowhunt", any first-time use where ActivityWatch is not yet running or connectors are not wired.

Action: read `setup.md` in this directory and follow its procedure end-to-end. It handles intake (5 questions + connector selection), then dispatches to `setup-activitywatch.md` (ActivityWatch install/launch) and `setup-connectors.md` (Gmail, Calendar, Task tracker, Slack, persist + exit).

## Mode: STATUS

Trigger phrases: `flowhunt status`, `check flowhunt`, `what is connected`, `flowhunt health`, `status flowhunt`.

Action: read `status.md` and follow its procedure. Fast, read-only health check of all connected sources. No data collection, no analysis.

## Mode: QUICK-AUDIT

Trigger phrases: `flowhunt quick-audit`, `quick audit`, `szybki audyt`, `audit bez danych`, `co warto zautomatyzować szybko`.

Action: read `quick-audit.md` and follow its procedure. Produces an automation audit in ~2 minutes using only the user's stated context and manually-pasted tasks. No connectors, no ActivityWatch, no data scraping. This is the best entry point for new users who want value before committing to setup.

## Mode: DRY-RUN

Trigger phrases: `flowhunt dry-run`, `preview audit data`, `show me what you collected`, `co zebrałeś przed audytem`.

Action: read `dry-run.md` and follow its procedure. Collects all data exactly like a full audit, presents a privacy-friendly preview of counts and samples, asks user for confirmation, and only proceeds to analysis if approved.

## Mode: AUDIT

Trigger phrases: `flowhunt audit`, `run audit`, `audit my workflow`, `what should I automate`, `analyze my work patterns`, any request to produce or refresh the full audit report.

Action: read `audit.md` in this directory and follow its procedure end-to-end. It dispatches to three modules: `audit-precheck.md` (health checks + workflow context), `audit-collect.md` (data collection from all sources + raw dumps), and `audit-output.md` (analysis, report writing, user feedback, next actions).

## Mode: CONFIG

Trigger phrases: `flowhunt config`, `update flowhunt context`, `change my role`, `edit workflow context`, `update tasks`.

Action: read `~/.flowhunt/config.json` (or the most recent `raw/intake.json`). Show the user their current `workflow_context` and connector state. Let them edit fields (role, time_drains, sacred, goal, task_tracker mode) without re-running full setup. Write changes back to `config.json` and the next audit's `raw/intake.json`.

## Mode: DIFF

Trigger phrases: `flowhunt diff`, `porównaj z poprzednim audytem`, `co się zmieniło`, `diff audit`, `jak mi idzie`, `progress since last audit`.

Action: read `diff-audit.md` and follow its procedure. Compares two existing audit reports (most recent vs second most recent, or user-specified dates) and produces a progress summary: new patterns, resolved recommendations, shifting time allocation, new connectors added.

## Before you start any mode

1. Detect which agent you are running inside. Read `reference/environment.md` for the full table. Short version: `env | grep -E '^(CLAUDECODE|CODEX_THREAD_ID|OPENCODE_CLIENT|GEMINI_CLI)='` and match the marker. Memorize the result for the whole session — every later branch depends on it.
2. Note your sandbox constraints for that agent (see `reference/environment.md`). Most important: inside `codex`, GUI app launch, port binding, nohup, and `open -a` are all refused — plan around it, do not fight it.
3. Confirm `curl`, `jq`, and `bash` are available. Baseline assumptions.
4. Make sure `~/.flowhunt/audits/` exists (`mkdir -p ~/.flowhunt/audits`). This is the persistent output location.
5. If this is the first time the user runs FlowHunt, `~/.flowhunt/config.json` will not exist. Create it with `version: "1.2.0"`, `agent` detected, all connectors set to `connected: false`, and an empty `workflow_context`. See `reference/config-schema.md` for the exact schema.

## Philosophy

You are the LLM. This skill is not a web app, not a wrapper around an API, not a dispatcher. It is a set of **instructions and facts** you read and act on. When the audit prompt says "analyze", you do the analysis yourself — do not try to call Anthropic's / OpenAI's / anyone's API. Whatever model the user is running you with produces the output.

**No helper scripts.** FlowHunt used to ship `scripts/*.sh` wrappers around curl and AW queries, but every sandboxed agent (especially Codex) broke them in a different way. The skill is now pure markdown: facts in `reference/`, procedures in `setup.md` / `audit.md`, connector details in `connectors/`. You read the facts, write the Bash yourself, and adapt to whatever your environment allows. If `nohup` is refused in Codex's sandbox, you already know — you skip that path and delegate to the user.

Never invent URLs, MCP package names, or setup flows. Every connector has a dedicated markdown file in `connectors/` with verified instructions. Read the relevant file before instructing the user.

Never create a Google Cloud project or ask the user to. Every supported connector path deliberately avoids that. If no path works without GCP, skip that connector and tell the user why.

Respond in the user's language. If unclear, default to their most recent message's language.
