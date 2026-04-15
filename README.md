# flowhunt-skill

> Agent-native automation discovery. Plug it into Claude Code, Codex CLI, OpenCode, or Gemini CLI and get a no-bullshit audit of what you should automate first.

FlowHunt watches how you actually work — window titles from ActivityWatch, email volume, calendar meetings, Slack messages — then your agent reads the data, applies a focused analysis prompt, and writes a markdown report telling you exactly what to automate and what to leave alone.

No Next.js. No SQLite. No Google Cloud project. No API keys. The agent you already have is the LLM.

## Install

```bash
npx skills add heyneuron/flowhunt-skill
```

The skill drops into `~/.claude/skills/flowhunt/` and `~/.agents/skills/flowhunt/`, both of which are auto-discovered by Claude Code, OpenCode, and Gemini CLI. Codex CLI picks it up from `~/.agents/skills/`.

## Use

Two commands, both conversational. You talk to your agent like you always do.

```
you:   flowhunt setup
agent: (walks you through ActivityWatch install + connector wiring for
        Gmail / Calendar / Slack / optional messaging. Zero decisions unless
        you want to skip something.)

you:   flowhunt audit
agent: (pulls 30 days of data, applies the FlowHunt audit prompt,
        writes ~/.flowhunt/audits/YYYY-MM-DD.md, shows you the top findings
        inline.)
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
| WhatsApp | advanced | OSS `lharries/whatsapp-mcp` (ban-risk disclaimer) |

Everything either ships from a big vendor (Anthropic / OpenAI / Google / Meta / Atlassian) or is open source with a stable protocol underneath. No dependency on SaaS startups that may disappear.

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

The `audit.md` has six sections:

1. **Patterns** — specific repetitive work observed
2. **Automation recommendations** — what + how + estimated time saved
3. **Not worth automating** — things that need a human
4. **User-proposed automations** — the user's own pain points (asked at end of audit, highest priority)
5. **Estimated time saved** — single short number
6. **Summary** — two sentences, the #1 thing to automate first

Raw data is always persisted so you can re-analyze the same collection later with a different angle or a different agent — no need to re-fetch.

## Why a skill instead of a web app

The first version of FlowHunt was a Next.js app with a SQLite database, a frontend for browsing raw data, a settings page for API keys, and a dispatcher that called Anthropic / OpenAI / Codex / Ollama separately. It worked but:

- The frontend was mostly a dashboard over raw data nobody wanted to browse
- The API key dispatcher duplicated something every modern agent already does (LLM inference)
- Non-technical users had to create a Google Cloud project to connect Gmail
- Maintaining "one app that talks to four LLM providers" was a tax on every feature

This skill is the whole thing collapsed into markdown + four shell scripts. The agent that reads `SKILL.md` is already the LLM. Gmail OAuth is already brokered by Anthropic / OpenAI / Google. SQLite is replaced by markdown files in `~/.flowhunt/audits/`. Every layer the old app used to own is now owned by something more durable.

## License

MIT. See [LICENSE](./LICENSE).

## Credits

- [ActivityWatch](https://activitywatch.net) — the fundamental local telemetry engine
- [BayramAnnakov/activitywatch-analysis-skill](https://github.com/BayramAnnakov/activitywatch-analysis-skill) — reference for category detection + death-loop heuristics
- [vercel-labs/skills](https://github.com/vercel-labs/skills) — the install path that makes one repo work across every agent
- Original [Heyneuron/flowhunt](https://github.com/Heyneuron/flowhunt) — the audit system prompt ported here is the core IP

Built by [HeyNeuron](https://heyneuron.com).
