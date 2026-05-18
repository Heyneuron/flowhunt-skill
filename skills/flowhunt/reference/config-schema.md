# FlowHunt central config schema

FlowHunt stores its persistent state in `~/.flowhunt/config.json`. This file is written during `setup.md` Step 1, updated during connector wiring, and read by `status.md`, `audit.md`, and any future command that needs to know what is connected.

## Why this file exists

Without a central config, every subsequent FlowHunt command has to:
- Parse the most recent `raw/intake.json` to discover what the user connected
- Guess whether ActivityWatch is installed
- Re-ask the user which agent they are on

A single config file makes the skill **stateful** and commands like `flowhunt status` or `flowhunt quick-audit` possible without re-running setup.

## Schema

```json
{
  "$schema": "https://flowhunt.heyneuron.com/config-schema.json",
  "version": "1.2.0",
  "created_at": "2026-05-15T10:00:00+02:00",
  "last_setup_at": "2026-05-15T10:00:00+02:00",
  "last_audit_at": null,
  "agent": "claude-code",
  "language": "pl",
  "connectors": {
    "activitywatch": {
      "installed": true,
      "running": true,
      "browser_extension": true,
      "os": "macos"
    },
    "email": {
      "provider": "gmail",
      "connected": true,
      "account": "user@gmail.com"
    },
    "calendar": {
      "provider": "google",
      "connected": true,
      "account": "user@gmail.com"
    },
    "task_tracker": {
      "provider": "linear",
      "connected": true,
      "manual_path": null
    },
    "slack": {
      "connected": true,
      "workspace": "mycompany"
    },
    "messaging": {
      "imessage": false,
      "telegram": false,
      "discord": false
    },
    "additional_accounts": [
      {
        "type": "email",
        "provider": "gmail",
        "connected": true,
        "account": "work@company.com",
        "label": "służbowy"
      },
      {
        "type": "slack",
        "provider": "slack",
        "connected": true,
        "workspace": "client-workspace",
        "label": "klient A"
      }
    ]
  },
  "workflow_context": {
    "role": "CTO startupu B2B SaaS",
    "time_drains": ["triage maila", "raporty w piątki"],
    "failed_attempts": ["Zapier"],
    "sacred": ["1:1 z ludźmi"],
    "goal": "oszczędzić 8h/tydz"
  }
}
```

## Field reference

| Field | Type | Description |
|---|---|---|
| `version` | string | Skill version that wrote this config. Used for migration logic if schema changes. |
| `created_at` | ISO8601 | First setup timestamp. |
| `last_setup_at` | ISO8601 | Most recent `flowhunt setup` run (idempotent updates bump this). |
| `last_audit_at` | ISO8601 \| null | Most recent `flowhunt audit` or `flowhunt quick-audit` run. |
| `agent` | string | Detected agent harness: `claude-code`, `codex`, `gemini`, `opencode`, `unknown`. |
| `language` | string | User's preferred language (ISO 639-1). |
| `connectors` | object | Truth table of what is wired. Every command reads this before probing. |
| `connectors.additional_accounts` | array | Optional secondary accounts (e.g. second Gmail, additional Slack workspace). Each entry has `type`, `provider`, `connected`, `account`/`workspace`, and an optional `label`. Audit iterates over these after the primary account. |
| `workflow_context` | object | The 5 intake answers (WC1-WC5). Written once during setup, editable via `flowhunt config`. |

## Rules for agents

1. **Write on first setup.** `setup.md` Step 0 must create `~/.flowhunt/` and write an initial `config.json` with `agent` detected and all connectors set to `connected: false`.
2. **Update atomically.** After each connector succeeds in `setup.md`, flip `connectors.<name>.connected = true` and bump `last_setup_at`.
3. **Never assume it exists.** In sandboxed agents (`codex`), file reads can fail. If `config.json` is missing, fall back to the legacy behavior (parse latest `raw/intake.json` or ask the user).
4. **Editable by user.** `flowhunt config` allows the user to update `workflow_context` fields or flip connector flags without re-running setup.

## Windows date helper

Because `config.json` uses ISO8601, generate timestamps with Python (works on every OS including Windows):

```bash
python3 -c "import datetime,json; print(datetime.datetime.now(datetime.timezone.utc).isoformat())"
```

Or for pure Bash cross-platform (macOS/Linux only; on Windows use the Python one-liner):

```bash
date -u +"%Y-%m-%dT%H:%M:%S+00:00"
```
