# flowhunt-skill

> Agent-native automation discovery. Plug it into Claude Code, Codex CLI, OpenCode, or Gemini CLI and get a no-bullshit audit of what you should automate first.

FlowHunt analyzes how you actually work — email content and volume, calendar meetings, Slack messages, task-tracker backlog, Notion documents, and optionally window titles from ActivityWatch — then your agent reads the data, applies a focused analysis prompt, and writes a markdown report telling you exactly what to automate and what to leave alone. All local. The agent you already have is the brain.

**Works immediately after setup** — no waiting period. ActivityWatch is optional but recommended: it adds time-per-app data that makes the second audit (after 14-30 days) significantly richer.

## Install

```bash
npx skills add heyneuron/flowhunt-skill
```

The skill drops into `~/.claude/skills/flowhunt/` and `~/.agents/skills/flowhunt/`, both of which are auto-discovered by Claude Code, OpenCode, and Gemini CLI. Codex CLI picks it up from `~/.agents/skills/`.

**Step-by-step guide (PL):** [flowhunt.heyneuron.com/instalacja](https://flowhunt.heyneuron.com/instalacja) — includes Node.js setup, agent installation, and a video walkthrough.

## Commands

All commands are conversational. You talk to your agent like you always do.

### `flowhunt setup`

First-time onboarding. The agent asks 5 workflow-context questions (role, time drains, failed attempts, sacred areas, goal), then wires connectors and optionally installs ActivityWatch. Re-running updates instead of starting from scratch.

### `flowhunt status`

Fast dashboard of what is connected, running, or broken — no data collection, no analysis. Completes in <10 seconds.

### `flowhunt quick-audit`

Produces an automation audit in ~2 minutes using only your stated context and manually-pasted tasks. No connectors, no ActivityWatch. Best entry point for new users who want value before committing to setup.

### `flowhunt dry-run`

Collects all data exactly like a full audit, then presents a privacy-friendly preview (counts + samples) and asks for your confirmation before analysis. Great when you want to see exactly what will be fed into the LLM.

### `flowhunt audit`

The full audit. Pulls data from every connected source, applies the analysis prompt, dumps raw data to `~/.flowhunt/audits/YYYY-MM-DD/raw/`, writes a markdown report, shows top findings inline, asks what YOU would automate, and offers next actions. If a previous audit exists, it automatically generates a **"Changes since last audit"** section.

### `flowhunt config`

Edit your workflow context, toggle connectors, or update manual tasks without re-running the full setup interview.

### `flowhunt diff`

Compares two existing audit reports and produces a progress summary: new patterns, resolved recommendations, shifting time allocation, new connectors added.

---

## What it reads

| Source | Status | How |
|---|---|---|
| ActivityWatch (window titles, app usage, browser URLs) | optional | direct HTTP to `localhost:5600` — zero MCP needed. Auto-discovers bucket names if the default pattern fails |
| Gmail | primary | native connector per agent (Anthropic / ChatGPT / Google OAuth) or IMAP + App Password fallback. **Multi-account supported** |
| Google Calendar | primary | same |
| Task tracker (Linear / Notion / Jira / ClickUp / Asana / Todoist / Trello) | primary | native connector per agent, community MCP, or manual paste to `~/.flowhunt/tasks.md` |
| **Notion documents** | extended read | if Notion is your task tracker, the audit also reads recent pages (SOPs, meeting notes, decision logs) |
| Slack | primary | native connector or OSS `korotovsky/slack-mcp-server`. Cookie tokens (`xoxc`/`xoxd`) rotate after weeks/months — the agent warns you |
| iMessage (macOS) | optional | OSS `tink1005/imessage-mcp` |
| Telegram (bot) | optional | bot token via BotFather |
| Discord (bot) | optional | bot token via Discord Developer Portal |

Every connector path either ships from a big vendor (Anthropic / OpenAI / Google / Atlassian) or is open source with a first-party protocol underneath. No SaaS-broker dependencies that may disappear, and no unofficial bridges that risk platform bans — WhatsApp is deliberately out because the only path for personal accounts (whatsmeow-based bridges) carries a non-zero ban risk from Meta.

---

## What it outputs

A dated folder at `~/.flowhunt/audits/YYYY-MM-DD/` containing:

```
audit.md                      # the human-readable report
raw/
  activitywatch.json          # top-100 AFK-filtered AW query
  gmail.json                  # raw Gmail search response
  calendar.json               # raw Calendar events
  tasks.json | tasks.md       # task tracker output or manual paste
  notion_docs.json            # Notion pages/databases (if Notion is tracker)
  slack.json                  # if Slack was connected
  user-proposed.md            # your own automation ideas, recorded verbatim
  intake.json                 # what you answered during setup
```

`audit.md` has up to seven sections:

1. **Summary** — two sentences, the #1 thing to automate first
2. **Changes since last audit** — only when a previous audit exists (auto-generated diff)
3. **Patterns** — specific repetitive work observed in the data
4. **Automation recommendations** — what + how + estimated time saved
5. **Not worth automating** — things that look repetitive but actually need a human
6. **User-proposed automations** — your own pain points (asked at the end of the audit, highest priority)
7. **Data sources used this run** — what was connected, what failed, what was skipped

Raw data is always persisted so you can re-analyze the same collection later with a different angle or a different agent — no need to re-fetch.

---

## Central state

FlowHunt keeps a central config at `~/.flowhunt/config.json` so commands like `flowhunt status`, `flowhunt config`, and `flowhunt quick-audit` work without re-asking you everything. Setup is idempotent — re-running updates rather than starting from scratch.

---

## How the skill itself is structured

```
skills/flowhunt/
  SKILL.md                  # router — dispatches all commands
  setup.md                  # onboarding procedure (interview, Steps 0–1)
  setup-activitywatch.md    # ActivityWatch install / launch / verification (Step 2)
  setup-connectors.md       # Email, Calendar, Tasks, Slack, Messaging (Steps 3–7)
  audit.md                  # audit dispatch — routes to 3 sub-modules
  audit-precheck.md         # health checks + workflow context reuse
  audit-collect.md          # data collection from all sources + raw dumps
  audit-output.md           # analysis, report writing, user feedback, next actions
  audit-diff.md             # automated diff generation during audit
  diff-audit.md             # standalone diff mode
  dry-run.md                # preview collected data before analysis
  status.md                 # read-only health check
  quick-audit.md            # interview-only audit, no connectors
  config.md                 # edit context / connectors without full setup
  AGENTS.md                 # conventions for future maintainers
  prompts/
    audit-system-prompt.md  # the analysis prompt the agent applies to itself
  reference/
    environment.md          # per-agent env detection + sandbox constraints
    activitywatch-api.md    # AW curl + AQL cheat sheet + auto-discovery fallback
    audit-output-schema.md  # exact format for audit.md + raw/
    config-schema.md        # ~/.flowhunt/config.json schema
  connectors/
    activitywatch.md        # install per OS + browser extension
    google-workspace.md     # Gmail + Calendar per agent
    task-trackers.md        # Linear / Notion / Jira / ... per agent + Notion docs
    slack.md                # native connector + OSS fallback
    messaging.md            # iMessage / Telegram / Discord
```

No helper scripts. No API adapters. No dispatcher. The skill is pure markdown — facts in `reference/`, procedures in `setup.md` / `audit.md`, per-agent connector details in `connectors/`. The agent reads the facts, writes its own Bash / curl / MCP calls, and adapts to whatever its sandbox allows.

---

## License

MIT. See [LICENSE](./LICENSE).

## Credits

- [ActivityWatch](https://activitywatch.net) — the fundamental local telemetry engine
- [BayramAnnakov/activitywatch-analysis-skill](https://github.com/BayramAnnakov/activitywatch-analysis-skill) — reference for category detection and death-loop heuristics
- [vercel-labs/skills](https://github.com/vercel-labs/skills) — the install path that makes one repo work across every agent
