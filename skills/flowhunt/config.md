# FlowHunt config procedure

Trigger phrases: `flowhunt config`, `update flowhunt context`, `change my role`, `edit workflow context`, `update tasks`, `zmień kontekst`, `edytuj flowhunt`.

Goal: let the user view and edit their FlowHunt state without re-running the full setup interview. This is the escape hatch for "my role changed", "I switched task trackers", or "my goal is different now".

## Step 0 — load state

1. Read `~/.flowhunt/config.json` if it exists.
   - If missing, try the most recent `~/.flowhunt/audits/*/raw/intake.json` and port it into config format.
   - If neither exists, print: "Nie znalazłem konfiguracji FlowHunta. Odpal najpierw `flowhunt setup` lub `flowhunt quick-audit`." and stop.
2. Display the current config in a compact form:

```
Obecny stan FlowHunt:
  Rola: <workflow_context.role>
  Główne bóle: <time_drains joined>
  Święte: <sacred joined>
  Cel: <workflow_context.goal>

Podłączone źródła:
  ActivityWatch ... <yes/no>
  Gmail .......... <account / nie>
  Calendar ....... <account / nie>
  Task tracker ... <linear/notion/manual/nie>
  Slack .......... <workspace / nie>

Co chcesz zmienić?
  1. Kontekst (rola, bóle, święte, cel)
  2. Źródła danych (dodać/usunąć konektor)
  3. Zadania manualne (edytować ~/.flowhunt/tasks.md)
  4. Nic — dzięki
```

Wait for the user's choice. Do not proceed automatically.

## Step 1 — edit workflow context

If the user picks **1**, show each field with its current value and ask for the new value (or "pomiń" to keep it):

```
Obecna rola: "CTO startupu B2B SaaS"
Nowa rola (Enter = zostaw): ___
```

Ask in this order:
1. `role`
2. `time_drains` (ask for 1-3 items, comma-separated or one per line)
3. `failed_attempts`
4. `sacred`
5. `goal`

After all five, summarize changes:
```
Zmiany:
  rola: "CTO startupu B2B SaaS" → "VP Engineering w scale-upie"
  cel: "oszczędzić 8h/tydz" → "przejść z 60h na 45h tydzień"

Zapisać? (tak/nie)
```

If yes, update `config.json → workflow_context`, bump `last_setup_at`, and also write the updated context to `~/.flowhunt/audits/YYYY-MM-DD/raw/intake.json` using today's date so the next audit picks it up immediately.

## Step 2 — edit connectors

If the user picks **2**, show the current connector state and ask which one to toggle:

```
Obecne źródła:
  [1] ActivityWatch — podłączone
  [2] Gmail — podłączone (user@gmail.com)
  [3] Google Calendar — podłączone
  [4] Task tracker (Linear) — podłączone
  [5] Slack — niepodłączone
  [6] iMessage — pominięte

Wybierz numer żeby przełączyć, lub "nowy" żeby dodać nowe konto:
```

### Toggle existing connector

If the user picks a number:
- **Disconnect:** set `connected = false` in config.json. Do NOT revoke OAuth or delete tokens — just flip the flag. The user can reconnect later via `flowhunt setup`.
- **Reconnect:** if `connected = false` and the user wants to turn it on, delegate to the relevant section in `setup.md` (or its modular equivalent). For example: "Żeby podłączyć Slack, przejdziemy przez szybki setup konektora." Then run the Slack wiring from `setup.md` Step 5 for the detected agent.

### Add a new account (multi-account)

If the user says "nowy" or "dodaj konto":
```
Jakie źródło?
  1. Dodatkowy Gmail
  2. Dodatkowy Slack workspace
  3. Inne
```

Append a new entry to `config.json → connectors` with a suffix:
```json
{
  "connectors": {
    "email_primary": { "provider": "gmail", "connected": true, "account": "user@gmail.com" },
    "email_secondary": { "provider": "gmail", "connected": false, "account": null }
  }
}
```

Then run the wiring procedure from `setup.md` for that source. After success, set `connected: true` and save the account identifier.

**Note:** Multi-account collection is fully supported since v1.1. `audit-collect.md` iterates over `config.json → connectors.additional_accounts[]` and writes to suffixed raw files (`gmail_secondary.json`, `slack_secondary.json`, etc.).

## Step 3 — edit manual tasks

If the user picks **3**, read `~/.flowhunt/tasks.md` (if it exists), show the first 20 lines, and ask:

```
Obecna zawartość ~/.flowhunt/tasks.md:
---
<content>
---

Wklej nową zawartość (lub "pomiń"):
```

If they paste new content, overwrite the file. If they say "pomiń", leave it as-is.

## Step 4 — confirm and exit

Print the updated state and close:

```
Zaktualizowano ~/.flowhunt/config.json

Następny audit automatycznie użyje nowych ustawień.
Możesz odpalić:
  flowhunt audit       → pełny audyt
  flowhunt dry-run     → zbierz dane i pokaż podgląd przed analizą
  flowhunt quick-audit → szybki audyt bez zbierania danych
  flowhunt status      → sprawdź stan źródeł
  flowhunt diff        → porównaj z poprzednim audytem
```

## Rules

1. **Never delete tokens or credentials.** `config.md` only flips flags. If the user disconnects Gmail, the token stays in the agent's MCP config — we just stop using it in FlowHunt.
2. **Always write back to config.json.** This is the source of truth.
3. **Propagate to the latest audit folder.** If an audit folder exists for today, also update `raw/intake.json` there so a re-run in the same session sees the changes.
4. **One change at a time.** Do not ask the user to rewrite everything at once.
5. **No API keys.** Same rule as setup — never ask for Google Cloud, OpenAI, or Anthropic keys.
