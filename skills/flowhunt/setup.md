# FlowHunt setup procedure

This is the procedure you (the agent) follow when the user says "flowhunt setup" or equivalent. Read it top to bottom. Every step is specified deliberately; do not skip or reorder.

Your goal: leave the user with a working ActivityWatch installation plus at least one connector wired up (Gmail or Slack), so that `flowhunt audit` produces something valuable. The bar is "a lazy non-technical user gets through this without making any decisions". If the user would have to think, you make the decision for them and explain what you did.

## Step 0 — prepare

1. Create `~/.flowhunt/audits/` if it does not exist: `mkdir -p ~/.flowhunt/audits`.
2. Run `scripts/detect-agent.sh`. Store the result. Valid values: `claude-code`, `codex`, `opencode`, `gemini`, `unknown`. Every later branch uses this.
3. Tell the user what you detected in one sentence. Example: "Widzę, że jestem w Claude Code — będę dawał ci instrukcje pasujące do tego agenta."

If the result is `unknown`, proceed but warn the user that connector instructions will be generic OSS paths (IMAP, local MCPs). Do not bail — ActivityWatch still works.

## Step 1 — ActivityWatch

Run `scripts/aw-check.sh`. One of three outcomes.

### 1a. `OK`

Say "ActivityWatch już chodzi, zbiera dane. Przechodzimy dalej." Skip to Step 2.

### 1b. `NOT_RUNNING`

ActivityWatch is installed but not running. Launch it using `scripts/aw-start.sh`. Do NOT chain commands with `&&` — inside sandboxed shells (notably Codex CLI on macOS with seatbelt) chained commands silently drop subsequent steps when the first one is refused. Run each step separately and inspect each status line.

**Procedure (run each bullet as its own Bash call):**

1. Run `scripts/aw-start.sh`. Read the single-line output:
   - `ALREADY_RUNNING` — go straight to Step 2 of setup, ActivityWatch is healthy.
   - `LAUNCHED` — the launch command was accepted. Continue to bullet 2.
   - `FAILED:<reason>` or `UNSUPPORTED_OS` — skip to the manual fallback below.
2. Wait 10 seconds for the app to finish booting. Use Bash: `sleep 10`.
3. Run `scripts/aw-check.sh`. If `OK`, done. If still `NOT_RUNNING`, wait another 10 seconds and run it once more. On first launch macOS may be prompting the user for Accessibility / Screen Recording permissions — tell the user: "macOS prosi o uprawnienia do nagrywania ekranu i dostępności — zaakceptuj oba okna i wróć tutaj. ActivityWatch nie nagrywa ekranu, potrzebuje tego tylko do czytania tytułów okien."
4. If after two waits `aw-check.sh` is still `NOT_RUNNING`, fall through to the manual fallback.

**Manual fallback (when automated launch fails):**

Tell the user, in their language: "Nie mogłem odpalić ActivityWatch automatycznie (to się zdarza w piaskownicy niektórych agentów). Otwórz go ręcznie: na macOS kliknij ikonę w Applications albo użyj Spotlight (Cmd+Space → 'ActivityWatch'). Na Linuxie odpal `aw-qt` w osobnym terminalu. Na Windowsie z menu Start. Napisz 'gotowe' kiedy zobaczysz ikonkę w tray-u." Then wait for confirmation and re-run `aw-check.sh`.

Do not proceed to Step 2 until `aw-check.sh` returns `OK`.

### 1c. `NOT_INSTALLED`

Run `scripts/aw-install-hint.sh` to get the exact install command for this OS. Show it to the user and ask permission to run it. When they say yes, run it via Bash. For macOS Homebrew specifically: `brew install --cask activitywatch`.

After install, on macOS the first launch prompts for accessibility/screen-recording permissions. Explain: "macOS zapyta o uprawnienia do nagrywania ekranu i dostępności — zaakceptuj oba. ActivityWatch nie robi screenshotów, potrzebuje tego tylko do czytania tytułów okien." Then `open -a ActivityWatch` and re-check.

After ActivityWatch is running, you MUST guide the user to install the browser extension. Without it you only see app names, not URLs or page titles — half the value is gone. Open the relevant store URL in their default browser using `open` (macOS) / `xdg-open` (Linux) / `start` (Windows):

- Chrome / Brave / Edge: `https://chromewebstore.google.com/detail/activitywatch-web-watcher/nglaklhklhcoonedhgnpgddginnjdadi`
- Firefox: `https://addons.mozilla.org/en-US/firefox/addon/aw-watcher-web/`
- Safari: not supported via prebuilt extension — tell Safari users to switch default browser for FlowHunt purposes, or skip.

Wait for the user to confirm they installed it. Then re-run `aw-check.sh` to confirm the browser bucket appeared.

## Step 2 — Google Workspace (Gmail + Calendar)

Branch on the agent detected in step 0. Read the matching section from `connectors/google-workspace.md` and follow it. In short:

| Agent | What you do |
|---|---|
| `claude-code` | Open `https://claude.ai/settings/connectors` in the user's browser, tell them to click Connect next to Gmail and Google Calendar, wait, verify by attempting a Gmail tool call |
| `codex` | Tell the user to run `codex login` in another terminal if not already signed in, then open `https://chatgpt.com/apps` and enable Gmail + Calendar (or use `/apps` inside Codex composer), verify by listing available apps |
| `gemini` | Run `gemini extensions install https://github.com/gemini-cli-extensions/workspace` via Bash, verify by running `gemini extensions list` |
| `opencode` | Open `connectors/google-workspace.md` section "OpenCode — IMAP + App Password", walk the user through creating a Gmail App Password at `https://myaccount.google.com/apppasswords`, write the opencode.json MCP block, restart OpenCode |
| `unknown` | Fall through to the OpenCode IMAP path (universal) |

After each connector: **verify**. Do not trust the user's "done" — actually attempt a tool call (e.g. `mcp__claude_ai_Gmail__gmail_get_profile`) or run `curl` against the local MCP. If the verification fails, debug with the user before moving on.

For `opencode` users, Calendar has no clean path without a GCP project — skip Calendar and tell them: "Dla OpenCode nie ma czystej ścieżki do Calendar bez Google Cloud projektu. Pomijam. Jak kiedyś przesiądziesz się na Claude Code, Codex albo Gemini, flowhunt setup dołoży Calendar automatycznie."

## Step 3 — Slack

Ask: "Używasz Slacka w pracy? (tak/nie/pomiń)" — if the user pauses more than a breath, default to "tak" and proceed.

If yes, read `connectors/slack.md` and branch on agent:

- `claude-code` — `https://claude.com/connectors/slack` (requires Pro/Max; if user is Free tier, fall through to korotovsky OSS)
- `codex` — ChatGPT Apps connector (`/apps` or chatgpt.com/apps)
- `gemini` — `gemini mcp add slack` with korotovsky/slack-mcp-server command
- `opencode` — add korotovsky/slack-mcp-server to `opencode.json`
- `unknown` — korotovsky local MCP with a detailed "how to get xoxc/xoxd tokens from browser DevTools" walkthrough

Verify with a tool call or list command.

## Step 4 — messaging (optional)

Ask: "Chcesz podpiąć jeszcze jakąś komunikację? Opcje: iMessage (tylko macOS), WhatsApp (zaawansowane, ryzyko bana), Telegram (bot), Discord (bot). Większość ludzi skip-uje, nie ma przymusu."

Default is skip. If user wants one, read the relevant section of `connectors/messaging.md` or `connectors/whatsapp.md` and follow. Each has per-agent instructions and an explicit disclaimer for ban-risk / full-disk-access / dev-portal-required scenarios.

## Step 5 — confirm and exit

Print a summary:

```
Setup gotowy:
  ActivityWatch .................... [OK / OK + browser]
  Gmail ............................ [OK / skipped — reason]
  Calendar ......................... [OK / skipped — reason]
  Slack ............................ [OK / skipped — reason]
  iMessage / WhatsApp / Discord .... [OK / skipped — reason]

Żeby dostać pierwszy audit użyteczny, poczekaj minimum 7 dni
(najlepiej 14-30 dni) żeby ActivityWatch nazbierał dane. Potem
powiedz "flowhunt audit".
```

Do NOT run the audit immediately unless the user explicitly asks. A same-day audit on an empty bucket is useless and you will waste user's trust.

## Rules you must follow during setup

1. **Never ask for API keys.** No Google Cloud, no OpenAI keys, no Anthropic keys. If you are tempted to ask, you picked the wrong connector path — re-read the relevant file in `connectors/`.
2. **Never edit the user's shell rc without explicit permission.** If a connector needs an environment variable, tell the user to add it themselves and show them the exact line.
3. **Always verify after each connector.** Saying "done" without confirming kills the trust baseline for the whole audit flow.
4. **Default to skip on anything optional.** The user is lazy by design — give them a working minimum and let them expand later.
5. **Communicate every action you take via Bash before you run it.** "Odpalam `brew install --cask activitywatch` — to zajmie ~2 min." No silent execution.
