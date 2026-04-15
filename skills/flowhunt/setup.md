# FlowHunt setup procedure

This is the procedure you (the agent) follow when the user says "flowhunt setup" or equivalent. Read it top to bottom.

Your job: greet the user, understand what they use, adapt to whichever agent harness and sandbox you're running inside, and leave them with a working ActivityWatch install plus whatever connectors they asked for. No helper scripts — you have `bash`, `curl`, `jq`, and your own intelligence. The files in `reference/` tell you the facts (endpoints, env vars, sandbox quirks). You construct the commands yourself and adapt to what your environment allows.

Setup is a **conversation**, not a script. Greet the user, explain what FlowHunt is about to do, ask a few short questions, then execute. Never run a single Bash command before the user knows what you are about to do and why.

---

## Step 0 — prepare (silent)

1. Create the flowhunt directory: `mkdir -p ~/.flowhunt/audits`
2. Detect which agent you are. Read `reference/environment.md` for the full table. Short version: run `env | grep -E '^(CLAUDECODE|CODEX_THREAD_ID|OPENCODE_CLIENT|GEMINI_CLI)='` and match:
   - `CODEX_THREAD_ID` set → `codex`
   - `CLAUDECODE=1` → `claude-code`
   - `GEMINI_CLI=1` → `gemini`
   - `OPENCODE_CLIENT=1` → `opencode`
   - none → `unknown`
3. Store that value in your working memory. Every later step branches on it.
4. Also note sandbox constraints for that agent (from `reference/environment.md`). Most notably: **if you are in `codex`, GUI app launching, port binding, and `open -a` are all refused** — plan to delegate those to the user.

Do NOT print anything yet. Step 1 is where the user first sees you.

---

## Step 1 — greet the user and gather intent

### 1a. Greet + explain

Print a short intro in the user's language. Template (Polish version — translate to the user's language when different):

```
Cześć! Jestem FlowHunt. Zaraz obgadam z tobą twój codzienny workflow i podpowiem
co warto zautomatyzować w pierwszej kolejności.

Jak to działa:
  1. Zainstaluję lokalnie ActivityWatch - widzi tytuły twoich okien i stron
     (wszystko zostaje na twoim kompie, zero chmury)
  2. Podepnę twojego maila, kalendarz i slacka (jeśli używasz) przez
     oficjalne konektory twojego agenta - żadnych API keys, żadnego
     Google Cloud projektu
  3. Za ~7 dni kiedy ActivityWatch nazbiera dane, odpalisz "flowhunt audit"
     i dostaniesz raport z konkretnymi rekomendacjami automatyzacji

Setup zajmie ~5 minut. Idziemy?
```

Then announce the detected agent in one sentence, e.g.: "Widzę że jesteś w Codex CLI, więc podepnę konektory ścieżką dopasowaną do Codexa." If the agent is `codex`, add one more sentence: "Uprzedzam — Codex ma piaskownicę która blokuje uruchamianie GUI aplikacji, więc niektóre kroki poproszę cię o odklepanie ręcznie (nie próbuję ich pchać przez bash, bo się nie uda)."

Wait for the user's confirmation ("tak", "jedziemy", "ok") before continuing. If they say "nie", stop and thank them.

### 1b. Interview — one question at a time

Ask the questions below **one at a time**. Wait for each answer before asking the next.

**Q1 — email:**
> Z jakiego maila korzystasz do pracy?
> - Gmail / Google Workspace
> - Outlook / Microsoft 365
> - Inne (IMAP, Apple Mail, Proton, ...)
> - Pomiń

Record `email = gmail | outlook | other | skip`. For Outlook/other, warn: "Podepniemy przez IMAP z hasłem aplikacji, działa ale setup chwilę dłuższy niż Gmail. OK?"

**Q2 — calendar:**
> Czy używasz kalendarza którego ma dotknąć audit?
> - Google Calendar
> - Outlook Calendar
> - Pomiń

Record `calendar`. If `email = gmail` and user hesitates, default `calendar = google` and say so.

**Q3 — Slack:**
> Slack w pracy — używasz? Audit przeczyta twoje wiadomości (treść, nie tylko metadane) z kanałów w których jesteś, żeby wykryć konkretne wzorce typu "wysyłasz podobne statusy do tych samych osób". Wszystko lokalnie, zero chmury.
> - Tak / Nie / Pomiń

Record `slack`.

**Q4 — task tracker (this one is as important as email):**
> Gdzie trzymasz swoje zadania / TODO / backlog? Audit potrzebuje tego żeby wiedzieć co TY uważasz za ważne, a nie tylko co widać z ActivityWatch.
> - Linear
> - Notion (databases z taskami)
> - Jira / Confluence
> - ClickUp
> - Asana
> - Todoist
> - Trello
> - Żadne z powyższych (używam notatek / kartki / kalendarza / głowy) — wtedy cię poproszę o ręczne wklejenie
> - Pomiń

Record `task_tracker = linear | notion | jira | clickup | asana | todoist | trello | manual | skip`. See `connectors/task-trackers.md` for the per-agent wiring flow at install time (happens later in Step 6).

If the user picks `manual`, immediately ask:
> "Wklej tutaj listę zadań które teraz próbujesz pchać (z notatnika, maila, luźna lista, cokolwiek). Format dowolny — ja sobie poradzę."

Take whatever they paste and write it verbatim to `~/.flowhunt/tasks.md` via `cat > ~/.flowhunt/tasks.md` (or the Write tool if the user pasted multiline). This file is re-read by every audit. The user can also edit it directly any time.

If the user picks `skip`, don't ask anything else.

**Q5 — optional messaging (one compact question):**
> Coś jeszcze z komunikacji? (opcjonalne, większość skipuje)
> - iMessage (macOS) / Telegram (bot) / Discord (bot) / Pomiń wszystko

Record `optional_messaging` as a list (possibly empty).

**Note — WhatsApp is intentionally not on this list.** The only OSS path for personal WhatsApp accounts (whatsmeow-based bridges like `lharries/whatsapp-mcp`) carries a non-zero ban risk from Meta. Losing access to a personal WhatsApp account costs more than any audit saves. If the user asks "but what about WhatsApp?", explain the risk briefly and tell them we deliberately don't support it — they can still read `https://github.com/lharries/whatsapp-mcp` themselves if they want to experiment outside FlowHunt.

### 1c. Confirm the plan

Print a plan reflecting the answers:

```
Ok, plan na ten setup:
  [1] ActivityWatch - zainstaluje + wtyczka do przegladarki
  [2] Gmail - przez konektor twojego agenta
  [3] Google Calendar - jak wyżej
  [4] Linear - natywny konektor Claude Code
  [5] Slack - przez konektor albo OSS stealth mode
  [6] iMessage / Telegram / ... - pominę

Wystartuję instalacje ActivityWatch, potem przeprowadzę cię przez każdy
konektor. Jeśli coś nie zadziała w mojej piaskownicy, poproszę cię o 
odklepanie ręcznie. Jedziemy?
```

Adjust the list based on actual intake answers (replace `[4] Linear` with whichever tracker the user chose, omit lines for skipped connectors). Wait for confirmation. Then proceed to Step 2.

---

## Step 2 — ActivityWatch

### 2a. Network-capability probe (Codex sandbox early exit)

If your detected agent is `codex`, run this BEFORE the health check and interpret the result carefully:

```bash
curl -fsS --max-time 2 http://localhost:5600/api/0/info
```

- **200 + JSON with `version` field:** sandbox is permissive enough, AW is running. Continue to 2b.
- **exit 7 "Couldn't connect" at 0ms, AND you are in Codex:** ambiguous — either AW really isn't running, or the Codex sandbox is blocking network. Ask the user directly:
  > "Sprawdź czy ActivityWatch działa — wejdź w przeglądarce na `http://localhost:5600`. Widzisz dashboard?"
  >
  > - Jeśli TAK → jesteś w Codex `--full-auto` z sandboxem `workspace-write` który blokuje sieć (w tym localhost). FlowHunt nie zadziała w tym trybie. Trzy opcje:
  >   1. **Najłatwiej**: odpal flowhunt z interaktywnego `codex` (bez `exec --full-auto`) — interactive default to `on-request` i nie blokuje localhost.
  >   2. **Dev-only**: `codex exec -s danger-full-access --full-auto "flowhunt setup"` — wyłącza sandbox, tylko na własny risk.
  >   3. **Inny agent**: Claude Code, Gemini CLI, OpenCode — żaden z nich nie ma default sandboxa blokującego sieć.
  > - Jeśli NIE → AW faktycznie nie chodzi, przejdź do 2c (launch).

  Read `reference/environment.md` → section `codex` for the verified details. Do not try to curl-workaround it; no workaround exists at the curl level.

- **`curl: command not found`:** system is missing curl (extremely unusual). Ask user to install curl and stop.

For any other agent (`claude-code`, `gemini`, `opencode`, `unknown`), skip the ambiguous branch — a failed curl means AW is not running, go to 2c.

### 2b. Health check

(For non-Codex agents and for Codex sessions that passed the probe above.)

Run:

```bash
curl -fsS --max-time 2 http://localhost:5600/api/0/info
```

Three outcomes:
- **200 + JSON with `version` field:** AW server is up. Go to 2c (bucket check).
- **`Connection refused` / `Couldn't connect`:** AW not running. Go to 2d (launch).
- **`curl: command not found`:** system is missing curl (extremely unusual). Ask user to install curl and stop.

### 2c. Bucket health check

Even if the server responds, confirm the window watcher registered:

```bash
curl -fsS http://localhost:5600/api/0/buckets/ | jq -r 'keys[]' | grep aw-watcher-window
```

If that returns a bucket name, AW is fully healthy — say "ActivityWatch chodzi" and skip to Step 2e (browser extension check).

If empty, the tray app is on but watchers crashed. Tell the user to click the ActivityWatch tray icon → Open Dashboard, wait 10s, re-run the check.

### 2d. Launch ActivityWatch

**Branch on the agent you detected in Step 0:**

#### If agent = `codex`:
**Do not attempt to launch.** Codex's seatbelt sandbox refuses `open -a`, `nohup`, port binding, and writes to `~/Library/`. Direct launches of `aw-server` or `aw-qt` also fail (log file perms, nice syscall, port bind all denied). Every attempt wastes time.

Instead, tell the user directly, in their language:

> Jestem w piaskownicy Codexa więc nie mogę uruchomić ActivityWatch sam. Odpal proszę ręcznie:
> 
> - **macOS**: Cmd+Space → wpisz "ActivityWatch" → Enter. Przy pierwszym uruchomieniu macOS poprosi o uprawnienia do Accessibility i Screen Recording — zaakceptuj oba (AW nie nagrywa ekranu, potrzebuje tego tylko do tytułów okien).
> - **Linux**: w osobnym terminalu odpal `aw-qt &`.
> - **Windows**: Start menu → ActivityWatch.
> 
> Napisz "gotowe" jak zobaczysz ikonkę w tray-u.

Wait for confirmation, then re-run the health check from 2a. If still not responding, wait another 15 seconds (first launch + permission dialogs can take a while) and re-check. Do not improvise alternative launch methods — they will all fail the same way.

#### If agent = `claude-code`, `gemini`, `opencode`, or `unknown`:
You can probably launch it. On macOS:

```bash
open -a ActivityWatch
```

On Linux (in a non-blocking way — don't wait for it):

```bash
( aw-qt & ) > /dev/null 2>&1
```

On Windows, ask the user to launch from Start menu — `start` from WSL may or may not work.

After the launch command, `sleep 10`, then re-run the health check from 2a. On first macOS launch, also warn the user about the Accessibility / Screen Recording dialogs (AW doesn't record, just reads titles).

If after two retries (each with `sleep 10`) the server is still not responding, fall through to the `codex` manual fallback message above — whatever is going on, ask the user to launch it themselves.

### 2e. Browser extension (non-negotiable)

Read `connectors/activitywatch.md` section "CRITICAL: the browser extension is not optional". Without it, FlowHunt only sees application windows, not URLs or page titles — 50-70% of audit value is gone.

Point the user at the right store URL. Do NOT try to open a browser from Codex sandbox — it fails. Print the URL prominently and ask the user to click:

- **Chromium** (Chrome / Brave / Edge / Arc / Opera / Vivaldi): https://chromewebstore.google.com/detail/activitywatch-web-watcher/nglaklhklhcoonedhgnpgddginnjdadi
- **Firefox**: https://addons.mozilla.org/en-US/firefox/addon/aw-watcher-web/
- **Safari**: no prebuilt extension; ask them to switch default browser or skip.

On agents where GUI browser opening works (`claude-code`, `gemini`, `opencode` typically), you can try:
```bash
open "https://chromewebstore.google.com/detail/activitywatch-web-watcher/nglaklhklhcoonedhgnpgddginnjdadi"
```
but if it fails or you're in `codex`, just print the URL.

Wait for the user to say "added", then verify the web bucket exists:

```bash
curl -fsS http://localhost:5600/api/0/buckets/ | jq -r 'keys[]' | grep aw-watcher-web
```

If no web bucket appears, troubleshoot per `connectors/activitywatch.md` (common: extension needs "On all sites" permission, or Brave Shields blocking localhost:5600).

### 2f. Not installed

If `reference/activitywatch-api.md` health check returned connection refused AND there's no `/Applications/ActivityWatch.app` (macOS) / no `aw-qt` on PATH (Linux), AW is not installed. Install it:

- **macOS**: `brew install --cask activitywatch` (warn: ~30MB download). If Homebrew is missing, point the user at https://brew.sh.
- **Linux**: no apt package. Point the user at https://activitywatch.net/downloads/ and wait for them to install.
- **Windows**: `winget install ActivityWatch.ActivityWatch` if winget is available, otherwise downloads page.

In the `codex` sandbox, even `brew install` will be refused — tell the user to run it themselves in a separate terminal.

After install, go back to 2d (launch).

---

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

Branch on `task_tracker` from Step 1b. Read `connectors/task-trackers.md` for the per-agent wiring details and the exact verification call for each tracker.

- `linear` / `notion` / `jira` / `asana` — for `claude-code`, first inspect your available tool list for `mcp__claude_ai_Linear__*` / `mcp__claude_ai_Notion__*` / `mcp__claude_ai_Atlassian__*` / `mcp__claude_ai_Asana__*` — if present, the user already connected, skip install and verify with a list-projects call. If not present, direct the user to `https://claude.ai/settings/connectors` and walk them through. For `codex`, direct to `https://chatgpt.com/apps`. For `gemini`, run the `gemini mcp add` one-liner from `connectors/task-trackers.md`. For `opencode`, show the MCP block to paste into `opencode.json`.
- `clickup` / `todoist` / `trello` — no native connector exists for most agents. Use the community MCP server referenced in `connectors/task-trackers.md`, install via the per-agent MCP config flow. Verify by a list-tasks call.
- `manual` — the user already pasted their tasks in Step 1b and you wrote them to `~/.flowhunt/tasks.md`. Nothing to wire. Just confirm: "OK, zadania w ~/.flowhunt/tasks.md — audit przeczyta ten plik automatycznie. Możesz go edytować ręcznie kiedy chcesz."
- `skip` — skip silently. Audit will run without task-priority signal.

After each connector, **verify** with a real tool call (list projects, list tasks, get workspace). If verification fails, debug with the user before moving on.

## Step 5 — Slack (branches on intake)

If `slack = yes`, read `connectors/slack.md` and branch on agent:

- `claude-code` → `https://claude.com/connectors/slack` (Pro/Max only; Free tier → korotovsky OSS)
- `codex` → `https://chatgpt.com/apps` Slack
- `gemini` → `gemini mcp add slack stdio -- npx -y @korotovsky/slack-mcp-server` (you can run this, no sandbox issues)
- `opencode` → write korotovsky block into opencode.json
- `unknown` → korotovsky with DevTools xoxc/xoxd walkthrough

Verify with a tool call (list channels or similar).

If `slack = no` or `skip`, skip silently.

---

## Step 6 — Optional messaging (branches on intake)

For each item in `optional_messaging`, read the relevant section of `connectors/messaging.md` and follow it. Remember: inside `codex` sandbox, anything involving `open`, port binding, or GUI launch is refused — delegate those steps to the user with clear instructions.

If `optional_messaging` is empty, skip silently.

---

## Step 7 — Confirm and exit

Print a summary reflecting what actually got wired:

```
Setup gotowy:
  ActivityWatch .................... [OK / OK + browser]
  Gmail ............................ [OK / skipped — reason]
  Google Calendar .................. [OK / skipped — reason]
  Task tracker (Linear/...) ........ [OK / manual — ~/.flowhunt/tasks.md / skipped]
  Slack ............................ [OK / skipped — reason]
  iMessage / Telegram / ... ........ [OK / skipped — reason]

Żeby dostać pierwszy audit użyteczny, poczekaj minimum 7 dni
(najlepiej 14-30 dni) żeby ActivityWatch nazbierał dane. Potem
powiedz "flowhunt audit".

Jeśli coś zmieniło się w twoim stacku, odpal "flowhunt setup" jeszcze
raz — setup jest idempotentny, nie zepsuje istniejącej konfiguracji.
Jeśli używasz ~/.flowhunt/tasks.md (tryb manual), możesz go edytować
kiedy chcesz — audit przy następnym uruchomieniu przeczyta świeżą wersję.
```

Do NOT run the audit immediately unless the user explicitly asks.

---

## Rules you must follow during setup

1. **Greet and interview before running anything.** Step 1 is not optional.
2. **Never ask for API keys.** No Google Cloud, no OpenAI keys, no Anthropic keys.
3. **Never edit the user's shell rc without explicit permission.** Show them the exact line to add, don't write it yourself.
4. **Always verify after each connector** by actually making a tool call.
5. **Default to skip on anything optional.**
6. **Communicate every Bash action before running it.** "Odpalam `brew install --cask activitywatch` — to zajmie ~2 min."
7. **One intake question at a time.** No dump.
8. **In sandboxed environments (especially Codex), do not fight the sandbox.** If a launch fails once due to sandbox denial, do not try alternative launch methods (`nohup`, `aw-server` direct, Python http.server, PTY tricks, etc.) — they all fail for different reasons. Delegate to the user with clear manual instructions and move on. The sandbox is not a puzzle to solve; it is a permanent constraint to plan around.
9. **Never chain commands with `&&` in sandboxed shells.** Run each command in its own Bash turn so you can observe its exit code and stdout separately.
