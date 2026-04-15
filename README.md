# flowhunt-skill

> Agent-native automation discovery. Plug it into Claude Code, Codex CLI, OpenCode, or Gemini CLI and get a no-bullshit audit of what you should automate first.

FlowHunt watches how you actually work — window titles from ActivityWatch, email volume and content, calendar meetings, Slack messages, task-tracker backlog — then your agent reads the data, applies a focused analysis prompt, and writes a markdown report telling you exactly what to automate and what to leave alone. All local. The agent you already have is the brain.

## Install

```bash
npx skills add heyneuron/flowhunt-skill
```

The skill drops into `~/.claude/skills/flowhunt/` and `~/.agents/skills/flowhunt/`, both of which are auto-discovered by Claude Code, OpenCode, and Gemini CLI. Codex CLI picks it up from `~/.agents/skills/`.

## Use

Two commands, both conversational. You talk to your agent like you always do.

```
you:   flowhunt setup
agent: (walks you through ActivityWatch install, a 4-question intake,
        and connector wiring for Gmail / Calendar / task tracker /
        Slack / optional messaging. Zero decisions unless you want
        to skip something.)

you:   flowhunt audit
agent: (pulls 30 days of data from every connected source, applies
        the FlowHunt audit prompt, dumps raw data to
        ~/.flowhunt/audits/YYYY-MM-DD/raw/, writes a markdown report
        to audit.md, shows you the top findings inline, and asks
        what YOU would automate.)
```

## What it reads

| Source | Status | How |
|---|---|---|
| ActivityWatch (window titles, app usage) | core | direct HTTP to `localhost:5600` — zero MCP needed |
| Gmail | primary | native connector per agent (Anthropic / ChatGPT / Google OAuth) or IMAP + App Password fallback |
| Google Calendar | primary | same |
| Task tracker (Linear / Notion / Jira / ClickUp / Asana / Todoist / Trello) | primary | native connector per agent, community MCP, or manual paste to `~/.flowhunt/tasks.md` |
| Slack | primary | native connector or OSS `korotovsky/slack-mcp-server` |
| iMessage (macOS) | optional | OSS `tink1005/imessage-mcp` |
| Telegram (bot) | optional | bot token via BotFather |
| Discord (bot) | optional | bot token via Discord Developer Portal |

Every connector path either ships from a big vendor (Anthropic / OpenAI / Google / Atlassian) or is open source with a first-party protocol underneath. No SaaS-broker dependencies that may disappear, and no unofficial bridges that risk platform bans — WhatsApp is deliberately out because the only path for personal accounts (whatsmeow-based bridges) carries a non-zero ban risk from Meta, and losing your WhatsApp account is not worth saving a couple of hours in an audit.

## What it outputs

A dated folder at `~/.flowhunt/audits/YYYY-MM-DD/` containing:

```
audit.md                 # the human-readable report
raw/
  activitywatch.json     # top-100 AFK-filtered AW query
  gmail.json             # raw Gmail search response
  calendar.json          # raw Calendar events
  tasks.json | tasks.md  # task tracker output or manual paste
  slack.json             # if Slack was connected
  user-proposed.md       # user's own automation ideas, recorded verbatim
  intake.json            # what the user answered during setup
```

`audit.md` has six sections:

1. **Patterns** — specific repetitive work observed in the data
2. **Automation recommendations** — what + how + estimated time saved
3. **Not worth automating** — things that look repetitive but actually need a human
4. **User-proposed automations** — the user's own pain points (asked at the end of the audit, highest priority)
5. **Estimated time saved** — single short number
6. **Summary** — two sentences, the #1 thing to automate first

Raw data is always persisted so you can re-analyze the same collection later with a different angle or a different agent — no need to re-fetch.

## How the skill itself is structured

```
skills/flowhunt/
  SKILL.md                          # router — dispatches "flowhunt setup" vs "flowhunt audit"
  setup.md                          # onboarding procedure with per-agent branches
  audit.md                          # audit procedure with per-agent branches
  prompts/
    audit-system-prompt.md          # the analysis prompt the agent applies to itself
  reference/
    activitywatch-api.md            # AW curl + AQL cheat sheet
    environment.md                  # per-agent env detection + sandbox constraints
    audit-output-schema.md          # exact format for audit.md + raw/
  connectors/
    activitywatch.md                # install per OS + browser extension (mandatory)
    google-workspace.md             # Gmail + Calendar per agent
    task-trackers.md                # Linear / Notion / Jira / ... per agent
    slack.md                        # native connector + OSS fallback
    messaging.md                    # iMessage / Telegram / Discord
```

No helper scripts. No API adapters. No dispatcher. The skill is pure markdown — facts in `reference/`, procedures in `setup.md` / `audit.md`, per-agent connector details in `connectors/`. The agent reads the facts, writes its own Bash / curl / MCP calls, and adapts to whatever its sandbox allows.

## License

MIT. See [LICENSE](./LICENSE).

## Credits

- [ActivityWatch](https://activitywatch.net) — the fundamental local telemetry engine
- [BayramAnnakov/activitywatch-analysis-skill](https://github.com/BayramAnnakov/activitywatch-analysis-skill) — reference for category detection and death-loop heuristics
- [vercel-labs/skills](https://github.com/vercel-labs/skills) — the install path that makes one repo work across every agent
