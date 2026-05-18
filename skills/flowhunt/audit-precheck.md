# FlowHunt audit — precheck and context

This module covers the audit steps that happen **before any data collection**.

## Step 0 — precheck

1. Check if ActivityWatch is running (optional — audit works without it):

   ```bash
   curl -fsS --max-time 2 http://localhost:5600/api/0/info
   ```

   - **200 + JSON:** AW is running. Set `aw_available = true`. Proceed to check data volume (point 4).
   - **Connection refused / timeout:** AW is not running. Set `aw_available = false`. This is fine — audit will use other data sources (Gmail, Calendar, Slack, tasks). Inform the user: "ActivityWatch nie działa, ale audit pójdzie na podstawie maila, kalendarza i tasków. Zainstaluj AW i za 14-30 dni drugi audit będzie bogatszy."

2. Detect which agent you are (same table as `setup.md` Step 0 and `reference/environment.md`): check `CODEX_THREAD_ID`, `CLAUDECODE`, `GEMINI_CLI`, `OPENCODE_CLIENT`. Store the result.

3. Compute today's date (YYYY-MM-DD). Create the audit folder:

   ```bash
   TODAY=$(date +%Y-%m-%d)
   mkdir -p ~/.flowhunt/audits/${TODAY}/raw
   ```

   If `~/.flowhunt/audits/${TODAY}/audit.md` already exists, warn the user: "Mamy już dzisiejszy audit, chcesz nadpisać?" If they decline, exit. If they accept, continue — you will overwrite both the audit.md and raw/ files.

4. If `aw_available = true`, check how many days of AW data you have:

   ```bash
   curl -fsS http://localhost:5600/api/0/buckets/ | jq -r '.[] | select(.id | startswith("aw-watcher-window")) | .created'
   ```

   Parse the timestamp, compute days since creation. If less than 7 days, note it — include a thin-data warning in the report but proceed anyway.

## Step 0.5 — workflow context (mandatory)

The audit needs human-stated context to prioritize correctly. Pure pattern detection from telemetry produces generic recommendations. Knowing the user's role, pain points, failed attempts, sacred areas, and goal lets the audit rank findings against what actually matters.

Before collecting any data, check if you already have a `workflow_context` block (either from `~/.flowhunt/config.json`, from this session's `setup.md` interview, or from a previous `~/.flowhunt/audits/*/raw/intake.json`).

```bash
# Try config.json first (new in v1.1)
[ -f "$HOME/.flowhunt/config.json" ] && jq -r '.workflow_context // empty' "$HOME/.flowhunt/config.json"
```

If empty, fall back to the legacy path:

```bash
LATEST_INTAKE=$(ls -t ~/.flowhunt/audits/*/raw/intake.json 2>/dev/null | head -1)
[ -n "$LATEST_INTAKE" ] && jq -r '.workflow_context // empty' "$LATEST_INTAKE"
```

**If `workflow_context` exists and is recent (audit from last 30 days):** show it back to the user in 3 lines and ask: *"Mam zapisany twój kontekst z poprzedniego audita: rola = X, główne bóle = Y, cel = Z. Coś się zmieniło, czy jedziemy z tym samym?"* If they say "to samo" — reuse it. If they want changes — ask which fields and update.

**If `workflow_context` is missing or older than 30 days:** ask the 5 questions inline now. They are the same as `setup.md` 1b (WC1-WC5):

1. **Rola:** "Jednym zdaniem: czym się zajmujesz na co dzień?"
2. **Top time drains:** "Wymień 3 rzeczy które robisz manualnie kilka razy w tygodniu i denerwuje cię, że nie są zautomatyzowane"
3. **Failed attempts:** "Co próbowałeś już automatyzować i nie wyszło? (Zapier, skrypty, AI agenty). Wpisz 'nic' jak nic"
4. **Sacred:** "Co jest święte i nie chcesz tego automatyzować? Wpisz 'nic' jak wszystko fair game"
5. **Goal:** "Po co ci ten audyt? Konkretny efekt"

Ask **one at a time**, wait for each answer. After all five, summarize back ("rola: X | bóle: Y | święte: Z | cel: W — pasuje?") and let the user correct.

Store the answers in working memory as `workflow_context`. They will be written to `raw/intake.json` during collection and consumed by the system prompt as the highest-priority input during analysis.
