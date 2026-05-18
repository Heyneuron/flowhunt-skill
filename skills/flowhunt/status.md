# FlowHunt status procedure

Trigger phrases: `flowhunt status`, `check flowhunt`, `what is connected`, `flowhunt health`, `status flowhunt`.

Goal: give the user a fast dashboard of what is wired, what is running, and what is broken — without collecting audit data or performing analysis.

## Step 0 — load config

1. Read `~/.flowhunt/config.json` if it exists.
2. If missing, print: "Nie znalazłem ~/.flowhunt/config.json — najpierw odpal `flowhunt setup`.", then stop.
3. Detect agent (same probe as `setup.md` / `audit.md`).

## Step 1 — probe each connector

For every connector listed in `config.json → connectors`, run a lightweight health check. Do NOT collect full data (that's audit's job).

### ActivityWatch

```bash
curl -fsS --max-time 2 http://localhost:5600/api/0/info > /dev/null 2>&1 && echo "up" || echo "down"
```

- `up` → check browser extension bucket: `curl -fsS http://localhost:5600/api/0/buckets/ | jq -r 'keys[]' | grep aw-watcher-web | head -1`
  - If anything returned: `status = ok + browser`
  - If empty: `status = ok (no browser ext)`
- `down` → `status = not running`

If agent = `codex`, skip the curl and print: `status = unknown (Codex sandbox blocks localhost probes)`.

### Gmail / Email

Attempt a **minimal** read operation:

- `claude-code`: call `mcp__claude_ai_Gmail__gmail_get_profile` (or equivalent). If it returns an email address → `ok`. If tool error / not found → `error / not connected`.
- `codex`: inspect available tools for anything Gmail-related. If present → `ok`. If absent → `not connected`.
- `gemini`: run `gemini extensions list | grep workspace` (or equivalent). If workspace extension is present → `ok`.
- `opencode` / `unknown`: try `opencode mcp list` or look for the IMAP MCP tool. If present → `ok`.

### Google Calendar

Same branching as Gmail. For agents where Calendar shares the same connector as Gmail (Claude Code, Gemini), if Gmail is `ok` assume Calendar is `ok` unless the user explicitly skipped it in config.

### Task tracker

- Live connector: try `list_projects` or equivalent minimal call.
- Manual mode (`~/.flowhunt/tasks.md` exists): `status = manual`.
- Neither: `status = not connected`.

### Slack

Try `list_channels` or inspect available tools for Slack namespace. Same per-agent branching as Gmail.

### Optional messaging

Only probe what the user explicitly enabled in config (`imessage`, `telegram`, `discord`). Skip the rest silently.

## Step 2 — render the status board

Print a compact board in the user's language:

```
FlowHunt status — 2026-05-15
Agent: Claude Code | Język: pl

Źródła danych:
  ActivityWatch ............... [OK + wtyczka przeglądarki]
  Gmail (user@gmail.com) ...... [OK]
  Google Calendar ............. [OK]
  Task tracker (Linear) ....... [OK]
  Slack (mycompany) ........... [OK]
  iMessage .................... [pominięte]
  Telegram .................... [pominięte]

Ostatni audit: 2026-05-10 (5 dni temu)
Kontekst: CTO startupu B2B SaaS | cel: oszczędzić 8h/tydz

Szybkie akcje:
  • flowhunt audit      → nowy audyt
  • flowhunt dry-run    → zbierz dane i pokaż podgląd przed analizą
  • flowhunt quick-audit→ audyt bez zbierania danych (2 min)
  • flowhunt diff       → porównaj z poprzednim audytem
  • flowhunt config     → edytuj kontekst / rolę / cele
```

If anything is `error` or `not running`, add a one-line remediation hint under that row:
- ActivityWatch down → "Odpal ActivityWatch ręcznie (Cmd+Space → ActivityWatch)"
- Gmail error → "Sprawdź https://claude.ai/settings/connectors — może wymagana ponowna autoryzacja"
- Slack error → "Token xoxc mógł wygasnąć — zaloguj się ponownie do Slacka w przeglądarce i wyciągnij nowe tokeny"

## Step 3 — suggest next action

End with:

```
Co chcesz zrobić?
  1. Odpalić pełny audit (flowhunt audit)
  2. Podgląd danych przed analizą (flowhunt dry-run)
  3. Szybki audyt bez zbierania danych (flowhunt quick-audit)
  4. Porównać z poprzednim audytem (flowhunt diff)
  5. Zaktualizować kontekst / konektory (flowhunt config)
  6. Nic — dzięki, to wszystko
```

Wait for the user's choice. Do not proceed automatically.

## Rules

1. **Fast.** Status should complete in <10 seconds. No heavy data collection.
2. **Read-only.** Never write files, never modify config, never trigger OAuth flows.
3. **Honest about errors.** If a probe fails, say it failed and suggest one fix. Do not pretend everything is green.
4. **Codex sandbox.** If you cannot probe due to sandbox (network blocked), say `unknown (sandbox)` rather than `down`.
