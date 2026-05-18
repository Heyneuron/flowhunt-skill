# FlowHunt setup — ActivityWatch module

This module is called from `setup.md` Step 1d after the user confirms the plan. It installs, launches, and verifies ActivityWatch plus its browser extension.

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
