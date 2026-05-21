# flowhunt-skill

> Agent-native automation discovery. Plug it into Claude Code, Codex CLI, OpenCode, or Gemini CLI and get a no-bullshit audit of what you should automate first.

FlowHunt starts from what you **actually do on your computer** — every app, every window, how long, how often — and turns that into a short, honest report: what to automate, what to leave alone, and roughly what it'll save you. Your agent reads the data, applies a focused analysis prompt, and writes the report. All local. The agent you already have is the brain.

It is **not** an email tool, a calendar tool, or a "knowledge worker" tool. It reads your real workflow — whatever that workflow actually is.

## Works for any kind of work

The core data source is [ActivityWatch](https://activitywatch.net): a local, open-source tracker that records which apps and windows you use and for how long. It doesn't care what your job is — it sees everything on the machine, so the audit is about *your* work, not a generic office worker's.

- **Video production** — hours in Premiere / DaVinci / After Effects, render waits, repeated exports, time in OBS or a screen recorder, browser time inside YouTube Studio / Vimeo / a webinar platform, the same upload-rename-tag-thumbnail dance after every recording.
- **Developers** — context-switch cost between editor, terminal, browser, chat.
- **Designers** — Figma time vs. asset export vs. handoff.
- **Agency / ops** — how much of the week is actually email, meetings, status updates, and copy-paste between tools.
- **Sales** — CRM data entry, follow-up drafting, calendar tetris.

If you do it on a computer, ActivityWatch sees it, and FlowHunt can reason about it. Email, calendar, chat and tasks are *optional extra context* — useful, but not the point.

## Install

```bash
npx skills add heyneuron/flowhunt-skill
```

The skill drops into `~/.claude/skills/flowhunt/` and `~/.agents/skills/flowhunt/`, both of which are auto-discovered by Claude Code, OpenCode, and Gemini CLI. Codex CLI picks it up from `~/.agents/skills/`.

**Step-by-step guide (PL):** [flowhunt.heyneuron.com/instalacja](https://flowhunt.heyneuron.com/instalacja) — includes Node.js setup, agent installation, and a video walkthrough.

## Use

Two commands, both conversational. You talk to your agent like you always do.

```
you:   flowhunt setup
agent: (walks you through a 5-question intake, installs ActivityWatch,
        and optionally wires extra context — email, calendar, task
        tracker, chat. Zero decisions unless you want to skip something.)

you:   flowhunt audit
agent: (reads your ActivityWatch data — plus any extra source you
        connected — applies the FlowHunt audit prompt, dumps raw data
        to ~/.flowhunt/audits/YYYY-MM-DD/raw/, writes a markdown
        report to audit.md, shows you the top findings inline, asks
        what YOU would automate, and gives you a feedback link with
        a free automation playbook reward.)
```

## What it reads

| Source | Role | How |
|---|---|---|
| **ActivityWatch** (apps + window titles + time spent) | **core** | direct HTTP to `localhost:5600` — no MCP, no API key, no cloud. This is the signal that makes the audit about *your* job instead of a generic one. |
| Email — Gmail **or** Outlook / Microsoft 365 | optional | native connector per agent, or IMAP fallback. Volume + subjects + senders, read-only, never message bodies. |
| Calendar — Google **or** Microsoft 365 | optional | native connector per agent |
| Task tracker (Linear / Notion / Jira / ClickUp / Asana / Todoist / Trello) | optional | native connector, community MCP, or manual paste to `~/.flowhunt/tasks.md` |
| Slack | optional | native connector or OSS `korotovsky/slack-mcp-server` |
| iMessage (macOS) | optional | OSS `tink1005/imessage-mcp` |
| Telegram / Discord (bot) | optional | bot token via BotFather / Discord Developer Portal |

**Google or Microsoft — doesn't matter.** ActivityWatch is platform-neutral and needs no account at all, and the audit never depends on you living in Gmail. A Microsoft 365 shop gets the exact same audit: the only thing that changes is which email/calendar connector you wire — or whether you wire one at all, since the audit runs fine on ActivityWatch alone. Run it with zero cloud connectors and you still get a real report.

Every connector path either ships from a big vendor (Anthropic / OpenAI / Google / Atlassian) or is open source with a first-party protocol underneath. No SaaS-broker dependencies that may disappear, and no unofficial bridges that risk platform bans — WhatsApp is deliberately out because the only path for personal accounts (whatsmeow-based bridges) carries a non-zero ban risk from Meta, and losing your WhatsApp account is not worth saving a couple of hours in an audit.

## What it outputs

A dated folder at `~/.flowhunt/audits/YYYY-MM-DD/` containing:

```
audit.md                 # the human-readable report
raw/
  activitywatch.json     # top-100 AFK-filtered AW query
  gmail.json             # raw email search response, if email was connected
  calendar.json          # raw Calendar events, if connected
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
    activitywatch.md                # install per OS + browser extension (the core source)
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
