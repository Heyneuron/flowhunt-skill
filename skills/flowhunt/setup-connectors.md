# FlowHunt setup — connector wiring module

This module is called from `setup.md` Step 1d after ActivityWatch setup completes (or is skipped). It wires Email, Calendar, Task tracker, Slack, and optional messaging connectors.

## Step 3 — Email (branches on intake)

Read the matching section in `connectors/google-workspace.md`. Branch on `email`:

- `gmail` → follow the Google Workspace path for your detected agent
- `outlook` → inform user "Outlook nie jest w v1 przez natywne konektory, podepnę przez IMAP" and follow the IMAP fallback section with `outlook.office365.com:993`
- `other` → same as outlook with user-supplied IMAP host
- `skip` → "Pomiń mail zgodnie z twoim wyborem. Audit bedzie bez sygnału z maila."

**Per-agent Gmail paths:**

| Agent | What you do |
|---|---|
| `claude-code` | Tell user to visit `https://claude.ai/settings/connectors` and click Connect next to Gmail. Verify by calling `mcp__claude_ai_Gmail__gmail_get_profile`. |
| `codex` | Tell user to run `codex login` in another terminal (you cannot — sandbox) if not signed in, then visit `https://chatgpt.com/apps` and enable Gmail. Verify by inspecting `codex mcp list` or by asking the user to run a Gmail test from Codex composer `$Gmail`. |
| `gemini` | Run `gemini extensions install https://github.com/gemini-cli-extensions/workspace` (this works — no GUI, no port binding, just a file write). Verify with `gemini extensions list`. |
| `opencode` | Walk user through creating a Gmail App Password at `https://myaccount.google.com/apppasswords` (print URL, don't try to open). Write the opencode.json MCP block for them. Tell them to restart OpenCode. |
| `unknown` | Fall through to IMAP + App Password path (universal). |

After each connector, **verify**. Actually try a tool call. If verification fails, debug together.

---

## Step 4 — Calendar (branches on intake)

Branch on `calendar`:

- `google` → follow `connectors/google-workspace.md` Calendar section. For `codex`, `claude-code`, `gemini` the flow is identical to Gmail — same settings page, one extra click. For `opencode` there is no clean path → tell the user: "Dla OpenCode nie ma czystej ścieżki do Calendar bez Google Cloud projektu. Pomijam."
- `outlook` → no clean path in v1. Tell the user: "Outlook Calendar nie ma czystej ścieżki w v1 bez konta Azure. Pomijam."
- `skip` → skip.

---

## Step 4.5 — Task tracker (branches on intake)

Branch on `task_tracker` from Step 1c. Read `connectors/task-trackers.md` for the per-agent wiring details and the exact verification call for each tracker.

- `linear` / `notion` / `jira` / `asana` — for `claude-code`, first inspect your available tool list for `mcp__claude_ai_Linear__*` / `mcp__claude_ai_Notion__*` / `mcp__claude_ai_Atlassian__*` / `mcp__claude_ai_Asana__*` — if present, the user already connected, skip install and verify with a list-projects call. If not present, direct the user to `https://claude.ai/settings/connectors` and walk them through. For `codex`, direct to `https://chatgpt.com/apps`. For `gemini`, run the `gemini mcp add` one-liner from `connectors/task-trackers.md`. For `opencode`, show the MCP block to paste into `opencode.json`.
- `clickup` / `todoist` / `trello` — no native connector exists for most agents. Use the community MCP server referenced in `connectors/task-trackers.md` (now with verified repos and install snippets), install via the per-agent MCP config flow. Verify by a list-tasks call.
- `manual` — the user already pasted their tasks in Step 1c and you wrote them to `~/.flowhunt/tasks.md`. Nothing to wire. Just confirm: "OK, zadania w ~/.flowhunt/tasks.md — audit przeczyta ten plik automatycznie. Możesz go edytować ręcznie kiedy chcesz."
- `skip` — skip silently. Audit will run without task-priority signal.

After each connector, **verify** with a real tool call (list projects, list tasks, get workspace). If verification fails, debug with the user before moving on.

---

## Step 5 — Slack (branches on intake)

If `slack = yes`, read `connectors/slack.md` and branch on agent:

- `claude-code` → `https://claude.com/connectors/slack` (Pro/Max only; Free tier → korotovsky OSS)
- `codex` → `https://chatgpt.com/apps` Slack
- `gemini` → `gemini mcp add slack stdio -- npx -y @korotovsky/slack-mcp-server` (you can run this, no sandbox issues)
- `opencode` → write korotovsky block into opencode.json
- `unknown` → korotovsky with DevTools xoxc/xoxd walkthrough

Verify with a tool call (list channels or similar).

> **Token rotation reminder (Slack xoxc/xoxd only):** If the user is on `unknown` agent and you guided them through the DevTools cookie-token extraction (`xoxc`/`xoxd`), explicitly warn: "Ten token pochodzi z ciasteczka przeglądarki i wygasa po kilku tygodniach lub miesiącach (gdy wylogujesz się ze Slacka lub przeglądarka wyczyści sesję). Gdy Slack przestanie odpowiadać, wróć do setup i odśwież tokeny w DevTools → Application → Cookies."
> 
> If `codex` or `opencode` uses the korotovsky server with the same cookie-token flow, apply the same warning.

If `slack = no` or `skip`, skip silently.

---

## Step 6 — Optional messaging (branches on intake)

For each item in `optional_messaging`, read the relevant section of `connectors/messaging.md` and follow it. Remember: inside `codex` sandbox, anything involving `open`, port binding, or GUI launch is refused — delegate those steps to the user with clear instructions.

If `optional_messaging` is empty, skip silently.

---

## Step 6.5 — Multi-account (optional)

After wiring the primary account for each source, ask:

> Masz dodatkowe konta Gmail, Slack workspace'y lub inne źródła które chcesz podłączyć? (np. służbowy Gmail, workspace klienta na Slacku)
> - Tak / Nie

If yes, for each additional account:
1. Ask `type` (email / slack / calendar / task_tracker)
2. Ask `provider` (gmail / outlook / slack / etc.)
3. Ask `label` (human name, e.g. "służbowy", "klient A")
4. Run the same wiring procedure as for the primary account (Step 3–5 logic, branched on agent)
5. On success, append to `config.json → connectors.additional_accounts`:
   ```json
   {
     "type": "email",
     "provider": "gmail",
     "connected": true,
     "account": "work@company.com",
     "label": "służbowy"
   }
   ```

If the user says no, skip silently.

**Audit behavior (v1.1):** `audit-collect.md` collects from the primary account first, then iterates over `additional_accounts`. Each additional account writes to a suffixed raw file (`gmail_secondary.json`, `slack_secondary.json`, etc.). The analysis prompt treats all accounts as a single merged signal.

---

## Step 7 — Persist state and exit

### 7a. Write `~/.flowhunt/config.json`

Using the working-memory state collected during this setup run, write (or overwrite) `~/.flowhunt/config.json` following `reference/config-schema.md`. This makes the setup idempotent and enables `flowhunt status` without re-asking the user.

Key fields to set:
- `version`: copy from `SKILL.md` frontmatter
- `last_setup_at`: current ISO8601 timestamp
- `agent`: the detected agent
- `language`: the language you used during this conversation
- `connectors.*.connected`: true/false reflecting what actually succeeded
- `connectors.*.provider`: gmail/outlook/linear/notion/etc.
- `workflow_context`: the 5 answers from Step 1b

Use Python for the write to avoid cross-platform `date` and `jq` issues:

```bash
python3 -c "import json,datetime; cfg=json.load(open('$HOME/.flowhunt/config.json')); cfg['last_setup_at']=datetime.datetime.now(datetime.timezone.utc).isoformat(); json.dump(cfg,open('$HOME/.flowhunt/config.json','w'),indent=2)"
```

(Adjust the Python snippet to mutate the specific fields you tracked in working memory.)

### 7b. Print summary

Print a summary reflecting what actually got wired:

```
Setup gotowy:
  ActivityWatch .................... [OK / OK + browser]
  Gmail ............................ [OK / skipped — reason]
  Google Calendar .................. [OK / skipped — reason]
  Task tracker (Linear/...) ........ [OK / manual — ~/.flowhunt/tasks.md / skipped]
  Slack ............................ [OK / skipped — reason]
  iMessage / Telegram / ... ........ [OK / skipped — reason]

Konfiguracja zapisana do ~/.flowhunt/config.json

Możesz od razu odpalić "flowhunt audit" — audit działa z tym co masz
podpięte (mail, kalendarz, taski, Slack). Jeśli zainstalowałeś
ActivityWatch, drugi audit za 14-30 dni będzie znacznie bogatszy
o dane o tym ile czasu na co poświęcasz.

Szybkie komendy:
  flowhunt status      → sprawdź co jest podłączone
  flowhunt quick-audit → audyt bez zbierania danych (2 min)

Jeśli coś zmieniło się w twoim stacku, odpal "flowhunt setup" jeszcze
raz — setup jest idempotentny, nie zepsuje istniejącej konfiguracji.
Jeśli używasz ~/.flowhunt/tasks.md (tryb manual), możesz go edytować
kiedy chcesz — audit przy następnym uruchomieniu przeczyta świeżą wersję.
```

Do NOT run the audit immediately unless the user explicitly asks.
