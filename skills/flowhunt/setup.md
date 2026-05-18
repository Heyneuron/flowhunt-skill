# FlowHunt setup procedure

This is the procedure you (the agent) follow when the user says "flowhunt setup" or equivalent. Read it top to bottom.

Your job: greet the user, understand what they use, adapt to whichever agent harness and sandbox you're running inside, and leave them with a working ActivityWatch install plus whatever connectors they asked for. No helper scripts — you have `bash`, `curl`, `jq`, and your own intelligence. The files in `reference/` tell you the facts (endpoints, env vars, sandbox quirks). You construct the commands yourself and adapt to what your environment allows.

Setup is a **conversation**, not a script. Greet the user, explain what FlowHunt is about to do, ask a few short questions, then execute. Never run a single Bash command before the user knows what you are about to do and why.

This file handles Steps 0–1 (prepare + intake). After Step 1, you dispatch to:
- `setup-activitywatch.md` for Step 2 (ActivityWatch install / launch / verification)
- `setup-connectors.md` for Steps 3–7 (Email, Calendar, Task tracker, Slack, Messaging, persist + exit)

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
5. Initialize or read `~/.flowhunt/config.json`. If it does not exist, create it with the skeleton from `reference/config-schema.md` (all connectors `connected: false`, empty `workflow_context`). If it exists, read it — the user may be re-running setup to update connectors.

Do NOT print anything yet. Step 1 is where the user first sees you.

---

## Step 1 — greet the user and gather intent

### 1a. Greet + explain

Print a short intro in the user's language. Template (Polish version — translate to the user's language when different):

```
Cześć! Jestem FlowHunt. Zaraz obgadam z tobą twój codzienny workflow i podpowiem
co warto zautomatyzować w pierwszej kolejności.

Jak to działa:
  1. Podepnę twojego maila, kalendarz i slacka (jeśli używasz) przez
     oficjalne konektory twojego agenta - żadnych API keys, żadnego
     Google Cloud projektu
  2. Opcjonalnie zainstaluję ActivityWatch - widzi tytuły twoich okien
     i stron (wszystko lokalnie, zero chmury). Nie jest wymagany, ale
     daje lepszy obraz na co poświęcasz czas
  3. Od razu po setup możesz odpalić "flowhunt audit" i dostaniesz
     raport z rekomendacjami. Drugi audit po 30 dniach z ActivityWatch
     będzie jeszcze dokładniejszy

Setup zajmie ~5 minut. Idziemy?
```

Then announce the detected agent in one sentence, e.g.: "Widzę że jesteś w Codex CLI, więc podepnę konektory ścieżką dopasowaną do Codexa." If the agent is `codex`, add one more sentence: "Uprzedzam — Codex ma piaskownicę która blokuje uruchamianie GUI aplikacji, więc niektóre kroki poproszę cię o odklepanie ręcznie (nie próbuję ich pchać przez bash, bo się nie uda)."

Wait for the user's confirmation ("tak", "jedziemy", "ok") before continuing. If they say "nie", stop and thank them.

### 1b. Workflow context — kim jesteś i co cię boli

Before asking about connectors, ask the user 5 short open-ended questions about their actual work. **One question at a time.** Wait for each answer. Keep your prompts terse — no preamble, no "to świetne pytanie".

The point of this block is to give the audit a human-stated baseline. Pure pattern detection from telemetry produces generic recommendations ("you use Gmail a lot, automate it"). Knowing the user's role, pain points, what they already tried, what is off-limits, and their goal lets the audit prioritize correctly.

**WC1 — role:**
> Jednym zdaniem: czym się zajmujesz na co dzień? (np. "CTO startupu B2B SaaS", "freelance dev React/Solana", "sales w software house", "ops manager w e-commerce")

Record `role` (free-text, one line).

**WC2 — top time drains:**
> Wymień 3 rzeczy które robisz manualnie kilka razy w tygodniu i denerwuje cię, że jeszcze nie są zautomatyzowane. Mogą być duże ("triage maila") albo małe ("kopiuję te same dane między arkuszami"). Po jednym w linijce.

Record `time_drains` as a list of strings (1-3 entries, whatever the user gives).

**WC3 — failed attempts:**
> Co próbowałeś już automatyzować i nie wyszło? (Zapier się rozsypał, skrypt zardzewiał, AI agent halucynował, no-code był za sztywny). Nazwij ścieżki które mam pominąć w rekomendacjach. Jak nic — wpisz "nic".

Record `failed_attempts` as a list (possibly empty / `["nic"]` if user passes).

**WC4 — sacred areas:**
> Co jest święte i nie chcesz tego automatyzować? (np. "1:1 z ludźmi nie ruszamy", "pisanie postów na LinkedIn to mój flow", "discovery calls robię sam"). Jak wszystko fair game — wpisz "nic".

Record `sacred` as a list (possibly empty).

**WC5 — goal:**
> Po co ci ten audyt? Jaki konkretny efekt chcesz osiągnąć? (np. "oszczędzić 10h/tydz", "więcej deep work bez przerywników", "scale firmy bez powiększania zespołu", "ograniczyć inboxa do max 30min/dzień")

Record `goal` (free-text, one line).

After all five answers, summarize back to the user in 2-3 lines so they can correct anything before you proceed:

```
Okej, wstępnie mam tak:
  rola: <role>
  bóle: <time_drains joined by " | ">
  święte: <sacred joined by " | ">
  cel: <goal>

Pasuje, czy coś dopisać?
```

If they correct something, update the record. Then proceed to 1c. Store all five fields in the `workflow_context` object that will be written to `~/.flowhunt/config.json` and to `~/.flowhunt/audits/YYYY-MM-DD/raw/intake.json` during the next audit.

### 1c. Connector wiring — jakie masz narzędzia

Now ask the technical questions about which tools you'll wire up. **One at a time**, same as 1b. Wait for each answer.

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

Record `task_tracker = linear | notion | jira | clickup | asana | todoist | trello | manual | skip`. See `connectors/task-trackers.md` for the per-agent wiring flow at install time (happens later in `setup-connectors.md`).

If the user picks `manual`, immediately ask:
> "Wklej tutaj listę zadań które teraz próbujesz pchać (z notatnika, maila, luźna lista, cokolwiek). Format dowolny — ja sobie poradzę."

Take whatever they paste and write it verbatim to `~/.flowhunt/tasks.md` via `cat > ~/.flowhunt/tasks.md` (or the Write tool if the user pasted multiline). This file is re-read by every audit. The user can also edit it directly any time.

If the user picks `skip`, don't ask anything else.

**Q5 — optional messaging (one compact question):**
> Coś jeszcze z komunikacji? (opcjonalne, większość skipuje)
> - iMessage (macOS) / Telegram (bot) / Discord (bot) / Pomiń wszystko

Record `optional_messaging` as a list (possibly empty).

**Note — WhatsApp is intentionally not on this list.** The only OSS path for personal WhatsApp accounts (whatsmeow-based bridges like `lharries/whatsapp-mcp`) carries a non-zero ban risk from Meta. Losing access to a personal WhatsApp account costs more than any audit saves. If the user asks "but what about WhatsApp?", explain the risk briefly and tell them we deliberately don't support it — they can still read `https://github.com/lharries/whatsapp-mcp` themselves if they want to experiment outside FlowHunt.

### 1d. Confirm the plan

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

Adjust the list based on actual intake answers (replace `[4] Linear` with whichever tracker the user chose, omit lines for skipped connectors). Wait for confirmation. Then proceed to the modules.

---

## Step 2 — dispatch to modules

After the user confirms the plan in 1d, execute in order:

1. Read and follow `setup-activitywatch.md` end-to-end. It installs, launches, and verifies ActivityWatch plus the browser extension.
2. Read and follow `setup-connectors.md` end-to-end. It wires Email, Calendar, Task tracker, Slack, optional messaging, persists state to `~/.flowhunt/config.json`, and prints the final summary.

Both modules branch on the agent you detected in Step 0 and on the intake answers from Step 1c.

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
