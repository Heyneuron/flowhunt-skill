# FlowHunt setup procedure

This is the procedure you (the agent) follow when the user says "flowhunt setup" or equivalent. Read it top to bottom. Every step is specified deliberately; do not skip or reorder.

Your goal: leave the user with a working ActivityWatch installation plus whichever connectors they actually use, so that `flowhunt audit` produces something valuable. The bar is "a lazy non-technical user gets through this without making any decisions they shouldn't have to". When the user would have to think about something technical, you make the decision for them and explain what you did.

Setup is a **conversation**, not a script. Greet the user, explain what FlowHunt is about to do, ask a few short questions to personalize the plan, then execute. Never run a single command before the user knows what you are about to do and why.

---

## Step 0 — prepare (silent)

1. Create `~/.flowhunt/audits/` if it does not exist: `mkdir -p ~/.flowhunt/audits`.
2. Run `scripts/detect-agent.sh`. Store the result. Valid values: `claude-code`, `codex`, `opencode`, `gemini`, `unknown`. Every later branch uses this.
3. Do NOT print anything yet. This step is preparation — the greeting in Step 1 is the first thing the user sees.

---

## Step 1 — greet the user and gather intent

This is the first visible step. Do NOT skip it, even when the user clearly knows what FlowHunt does. Brief greeting, short explanation, and an interview that takes ~30 seconds.

### 1a. Greet + explain

Print a short intro in the user's language. Template (Polish version — translate to user's language when different):

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

Then announce which agent you detected, one sentence: "Widzę że jesteś w Codex CLI, więc podepnę konektory ścieżką dopasowaną do Codexa." (substitute the actual detected agent).

Wait for the user's confirmation (a "tak", "jedziemy", "ok", or equivalent) before continuing. If the user says "nie", stop and thank them.

### 1b. Interview — short, multiple choice where possible

Ask the questions below **one at a time**. Wait for each answer before asking the next. If the user's answer is ambiguous, ask for clarification; if unambiguous, record it and move on without commentary.

**Question 1 — email:**
> Z jakiego maila korzystasz do pracy?
> - Gmail / Google Workspace
> - Outlook / Microsoft 365
> - Inne (IMAP, Apple Mail, Proton, ...)
> - Pomiń (nie chcę wiązać maila)

Record `email = gmail | outlook | other | skip`. Note: in v1 FlowHunt fully supports Gmail. Outlook and "other" will be attempted through the universal IMAP fallback if the user really wants, but tell them: "Outlook / inne — podepniemy przez IMAP z hasłem aplikacji. Działa, ale setup jest chwilę dłuższy niż Gmail. Ok?" If they say no, set `email = skip`.

**Question 2 — calendar:**
> Czy używasz kalendarza którego ma dotknąć audit? Audit patrzy tylko na twój własny kalendarz, nie na firmowe wspólne.
> - Google Calendar (najczęściej z Gmailem)
> - Outlook Calendar
> - Pomiń

Record `calendar = google | outlook | skip`. If `email = gmail` and the user did not answer explicitly, default `calendar = google` and tell them: "Domyślnie podepnę też Google Calendar bo używasz Gmaila — powiedz jeśli mam pominąć." If `email = outlook` default `calendar = outlook` with the same note.

**Question 3 — Slack:**
> Slack w pracy — używasz? Jeśli tak, audit spojrzy tylko w kanały w których jesteś członkiem i policzy twoje wiadomości (bez czytania treści).
> - Tak
> - Nie
> - Pomiń

Record `slack = yes | no | skip`.

**Question 4 — optional messaging (compact single question):**
> Coś jeszcze z komunikacji do audytu? Te są opcjonalne, większość osób skipuje:
> - iMessage (tylko macOS)
> - WhatsApp (ryzyko bana, zaawansowane)
> - Telegram (przez bota)
> - Discord (przez bota)
> - Pomiń wszystko

Record `optional_messaging` as a list (possibly empty). Default to empty if the user hesitates or says "pomiń".

### 1c. Confirm the plan

Before touching anything, print a concrete plan based on the answers:

```
Ok, plan na ten setup:
  [1] ActivityWatch - zainstaluje + wtyczka do przegladarki (mandatory)
  [2] Gmail - przez natywny konektor twojego agenta
  [3] Google Calendar - jak wyżej
  [4] Slack - przez natywny konektor (Pro/Max) albo OSS stealth mode
  [5] iMessage - pominę
  [6] WhatsApp / Telegram / Discord - pominę

Wystartuję instalację ActivityWatch, potem przeprowadzę cię krok po kroku
przez każdy konektor. Jeśli coś pójdzie nie tak, powiem i wspólnie obgadamy
fallback. Jedziemy?
```

Adjust lines based on the actual intake answers. If the user confirms, proceed to Step 2. If they want to change something, adjust the plan and re-confirm.

**Important:** do NOT proceed to Step 2 without explicit confirmation on this plan. The user needs to feel in control before you start running Bash.

---

## Step 2 — ActivityWatch

Run `scripts/aw-check.sh`. One of three outcomes.

### 2a. `OK`

Say "ActivityWatch już chodzi, zbiera dane. Przechodzimy dalej." Skip to Step 3.

### 2b. `NOT_RUNNING`

ActivityWatch is installed but not running. Launch it using `scripts/aw-start.sh`. Do NOT chain commands with `&&` — inside sandboxed shells (notably Codex CLI on macOS with seatbelt) chained commands silently drop subsequent steps when the first one is refused. Run each step separately and inspect each status line.

**Procedure (run each bullet as its own Bash call):**

1. Run `scripts/aw-start.sh`. Read the single-line output:
   - `ALREADY_RUNNING` — go straight to Step 3, ActivityWatch is healthy.
   - `LAUNCHED` — the launch command was accepted. Continue to bullet 2.
   - `FAILED:<reason>` or `UNSUPPORTED_OS` — skip to the manual fallback below.
2. Wait 10 seconds for the app to finish booting. Use Bash: `sleep 10`.
3. Run `scripts/aw-check.sh`. If `OK`, done. If still `NOT_RUNNING`, wait another 10 seconds and run it once more. On first launch macOS may be prompting the user for Accessibility / Screen Recording permissions — tell the user: "macOS prosi o uprawnienia do nagrywania ekranu i dostępności — zaakceptuj oba okna i wróć tutaj. ActivityWatch nie nagrywa ekranu, potrzebuje tego tylko do czytania tytułów okien."
4. If after two waits `aw-check.sh` is still `NOT_RUNNING`, fall through to the manual fallback.

**Manual fallback (when automated launch fails):**

Tell the user, in their language: "Nie mogłem odpalić ActivityWatch automatycznie (to się zdarza w piaskownicy niektórych agentów). Otwórz go ręcznie: na macOS kliknij ikonę w Applications albo użyj Spotlight (Cmd+Space → 'ActivityWatch'). Na Linuxie odpal `aw-qt` w osobnym terminalu. Na Windowsie z menu Start. Napisz 'gotowe' kiedy zobaczysz ikonkę w tray-u." Then wait for confirmation and re-run `aw-check.sh`.

Do not proceed to Step 3 until `aw-check.sh` returns `OK`.

### 2c. `NOT_INSTALLED`

Run `scripts/aw-install-hint.sh` to get the exact install command for this OS. Show it to the user and ask permission to run it. When they say yes, run it via Bash. For macOS Homebrew specifically: `brew install --cask activitywatch`.

After install, on macOS the first launch prompts for accessibility/screen-recording permissions. Explain: "macOS zapyta o uprawnienia do nagrywania ekranu i dostępności — zaakceptuj oba. ActivityWatch nie robi screenshotów, potrzebuje tego tylko do czytania tytułów okien." Then run `scripts/aw-start.sh` → `sleep 10` → `scripts/aw-check.sh` as in 2b.

### 2d. Browser extension (non-negotiable)

After ActivityWatch is running, you MUST guide the user to install the browser extension. Without it you only see app names, not URLs or page titles — half the value is gone. Open the relevant store URL in their default browser using `open` (macOS) / `xdg-open` (Linux) / `start` (Windows):

- Chrome / Brave / Edge: `https://chromewebstore.google.com/detail/activitywatch-web-watcher/nglaklhklhcoonedhgnpgddginnjdadi`
- Firefox: `https://addons.mozilla.org/en-US/firefox/addon/aw-watcher-web/`
- Safari: not supported via prebuilt extension — tell Safari users to switch default browser for FlowHunt purposes, or skip.

Wait for the user to confirm they installed it. Then verify via:

```bash
curl -fsS http://localhost:5600/api/0/buckets/ | jq 'keys[] | select(test("aw-watcher-web"))'
```

If this returns a bucket name, the extension is connected. If empty, troubleshoot (see `connectors/activitywatch.md`).

---

## Step 3 — Email (based on intake)

Branch on `email` recorded in Step 1b:

- `gmail` → follow the Google Workspace path for the detected agent in `connectors/google-workspace.md`
- `outlook` → inform the user "Outlook nie jest w v1 przez natywne konektory, podepnę przez IMAP". Fall through to the universal IMAP fallback in `connectors/google-workspace.md` with Outlook IMAP settings (`outlook.office365.com:993` / `smtp.office365.com:587`).
- `other` → same as `outlook` with whichever IMAP host the user provides
- `skip` → print "Pomiń mail, zgodnie z twoim wyborem. Audit będzie bez sygnału z maila."

**Per-agent Gmail paths** (applies when `email = gmail`):

| Agent | What you do |
|---|---|
| `claude-code` | Open `https://claude.ai/settings/connectors` in the user's browser, tell them to click Connect next to Gmail, wait, verify by attempting a Gmail tool call |
| `codex` | Tell the user to run `codex login` in another terminal if not already signed in, then open `https://chatgpt.com/apps` and enable Gmail (or use `/apps` inside Codex composer), verify by listing available apps |
| `gemini` | Run `gemini extensions install https://github.com/gemini-cli-extensions/workspace` via Bash, verify by running `gemini extensions list` |
| `opencode` | Walk the user through creating a Gmail App Password at `https://myaccount.google.com/apppasswords`, write the opencode.json MCP block, restart OpenCode |
| `unknown` | Fall through to the OpenCode IMAP path (universal) |

After each connector: **verify**. Do not trust the user's "done" — actually attempt a tool call (e.g. `mcp__claude_ai_Gmail__gmail_get_profile`) or run `curl` against the local MCP. If the verification fails, debug with the user before moving on.

---

## Step 4 — Calendar (based on intake)

Branch on `calendar`:

- `google` → follow the Google Calendar path for the detected agent in `connectors/google-workspace.md`. The native connector flow is identical to Gmail (one click on the same settings page for Claude / ChatGPT / Gemini).
- `outlook` → no clean path in v1 (same Azure app registration burden as Teams). Tell the user: "Outlook Calendar nie ma czystej ścieżki w v1 bez konta Azure. Pomijam. Jak przesiądziesz się kiedyś na Google Calendar, flowhunt setup podepnie automatycznie."
- `skip` → skip.

For `opencode` users with `calendar = google`: there is no clean path without a GCP project. Skip Calendar and tell them: "Dla OpenCode nie ma czystej ścieżki do Calendar bez Google Cloud projektu. Pomijam. Jak kiedyś przesiądziesz się na Claude Code, Codex albo Gemini, flowhunt setup dołoży Calendar automatycznie."

---

## Step 5 — Slack (based on intake)

If `slack = yes`, read `connectors/slack.md` and branch on agent:

- `claude-code` — `https://claude.com/connectors/slack` (requires Pro/Max; if user is Free tier, fall through to korotovsky OSS)
- `codex` — ChatGPT Apps connector (`/apps` or chatgpt.com/apps)
- `gemini` — `gemini mcp add slack` with korotovsky/slack-mcp-server command
- `opencode` — add korotovsky/slack-mcp-server to `opencode.json`
- `unknown` — korotovsky local MCP with a detailed "how to get xoxc/xoxd tokens from browser DevTools" walkthrough

Verify with a tool call or list command.

If `slack = no` or `skip`, skip the step silently.

---

## Step 6 — Optional messaging (based on intake)

For each item in `optional_messaging` from Step 1b, read the relevant section of `connectors/messaging.md` or `connectors/whatsapp.md` and follow it. Each has per-agent instructions and an explicit disclaimer for ban-risk / full-disk-access / dev-portal-required scenarios.

If `optional_messaging` is empty, skip the step silently.

---

## Step 7 — Confirm and exit

Print a summary that reflects what actually got wired, not what the intake asked for:

```
Setup gotowy:
  ActivityWatch .................... [OK / OK + browser]
  Gmail ............................ [OK / skipped — reason]
  Google Calendar .................. [OK / skipped — reason]
  Slack ............................ [OK / skipped — reason]
  iMessage / WhatsApp / ... ........ [OK / skipped — reason]

Żeby dostać pierwszy audit użyteczny, poczekaj minimum 7 dni
(najlepiej 14-30 dni) żeby ActivityWatch nazbierał dane. Potem
powiedz "flowhunt audit".

Jeśli po drodze coś zmieniło się w twoim stacku (inne konto Gmail, nowy
Slack, itp.) odpal "flowhunt setup" jeszcze raz i zmień odpowiedzi w
wywiadzie. Setup jest idempotentny - nie zepsuje istniejącej konfiguracji.
```

Do NOT run the audit immediately unless the user explicitly asks. A same-day audit on an empty bucket is useless and you will waste user's trust.

---

## Rules you must follow during setup

1. **Greet and interview before running anything.** Step 1 is not optional. Do not touch `brew install` before the user has seen the plan and confirmed.
2. **Never ask for API keys.** No Google Cloud, no OpenAI keys, no Anthropic keys. If you are tempted to ask, you picked the wrong connector path — re-read the relevant file in `connectors/`.
3. **Never edit the user's shell rc without explicit permission.** If a connector needs an environment variable, tell the user to add it themselves and show them the exact line.
4. **Always verify after each connector.** Saying "done" without confirming kills the trust baseline for the whole audit flow.
5. **Default to skip on anything optional.** The user is lazy by design — give them a working minimum and let them expand later.
6. **Communicate every action you take via Bash before you run it.** "Odpalam `brew install --cask activitywatch` — to zajmie ~2 min." No silent execution.
7. **Never chain commands with `&&` inside sandboxed agent shells** (Codex seatbelt especially). Run each command in its own Bash turn so you can observe exit codes and stdout separately.
8. **One intake question at a time.** The interview in Step 1b must not dump all four questions at once. The user answers Q1, you record, you ask Q2. This is the difference between feeling served and feeling interrogated.
