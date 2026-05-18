# FlowHunt quick-audit procedure

Trigger phrases: `flowhunt quick-audit`, `quick audit`, `szybki audyt`, `audit bez danych`, `co warto zautomatyzować szybko`.

Goal: produce an automation audit in ~2 minutes using **only** the user's stated context and manually-pasted tasks. No connectors, no ActivityWatch, no Gmail/Slack scraping. This lowers the barrier to entry dramatically — a user can get value before installing anything.

## When to use

- User has not run `flowhunt setup` yet and wants to see what FlowHunt is about.
- User is in a sandboxed environment (Codex `workspace-write`) where data collection is impossible.
- User wants a "second opinion" without waiting for data collection.
- All connectors are temporarily broken and the user still wants advice.

## Output

Same folder layout as full audit, but `raw/` only contains `intake.json` and optionally `tasks.md`:

```
~/.flowhunt/audits/2026-05-15/
  audit.md
  raw/
    intake.json
    tasks.md          # only if user pasted tasks
```

## Step 0 — setup check (optional but recommended)

If `~/.flowhunt/config.json` exists, read `workflow_context` from it and skip to Step 2 (confirmation). If it does not exist, proceed to Step 1 (inline intake).

## Step 1 — inline intake (same 5 questions)

Ask the 5 workflow-context questions one at a time, exactly as in `setup.md` Step 1b:

1. **Role:** "Jednym zdaniem: czym się zajmujesz na co dzień?"
2. **Top time drains:** "Wymień 3 rzeczy które robisz manualnie i denerwuje cię, że nie są zautomatyzowane."
3. **Failed attempts:** "Co próbowałeś już automatyzować i nie wyszło? Wpisz 'nic' jak nic."
4. **Sacred areas:** "Co jest święte i nie chcesz tego automatyzować? Wpisz 'nic' jak wszystko fair game."
5. **Goal:** "Po co ci ten audyt? Jaki konkretny efekt chcesz osiągnąć?"

After all five, summarize back and ask for corrections (same pattern as `setup.md`).

Then ask one extra question:

> **Zadania:** Wklej tutaj listę zadań / TODO / backlog które teraz próbujesz pchać (z notatnika, głowy, maila). Format dowolny — ja sobie poradzę. Jeśli nie masz nic pod ręką, wpisz "pomiń".

If they paste tasks, write them to `raw/tasks.md` in the audit folder.

## Step 2 — write intake.json

Create the audit folder and write `raw/intake.json`:

```bash
TODAY=$(date +%Y-%m-%d)
mkdir -p ~/.flowhunt/audits/${TODAY}/raw
```

```json
{
  "quick_audit": true,
  "agent": "<detected_agent>",
  "language": "<user_language>",
  "workflow_context": {
    "role": "...",
    "time_drains": ["..."],
    "failed_attempts": ["..."],
    "sacred": ["..."],
    "goal": "..."
  },
  "data_sources": {
    "activitywatch": false,
    "gmail": false,
    "calendar": false,
    "tasks": "manual",
    "slack": false
  }
}
```

## Step 3 — apply the audit prompt

Load `prompts/audit-system-prompt.md`. Your input data is:

1. `workflow_context` (highest priority)
2. `tasks.md` content (if provided)
3. **No telemetry.** Do not invent ActivityWatch patterns, email counts, or Slack stats. The prompt's priority ordering still applies, but slots 2-7 are empty or minimal.

Because you have no telemetry, lean heavily on **pattern libraries** — common automation recipes for the user's role. For example:
- A "CTO of B2B SaaS" almost certainly deals with investor updates, hiring pipelines, and sprint reviews.
- A "freelance React dev" almost certainly deals with repetitive client onboarding, timesheets, and deployment checks.

Use the role + time_drains to match against known patterns, but **be explicit** that these are inferred from role stereotypes, not from personal data:

> "Nie mam twoich danych z ActivityWatch ani maila, więc poniższe rekomendacje opierają się na Twoim opisie roli i typowych wzorcach dla tego stanowiska. Pełny audit po podłączeniu źródeł będzie znacznie dokładniejszy."

## Step 4 — write audit.md

Use the exact same schema as `reference/audit-output-schema.md`. Frontmatter must include:

```yaml
---
date: 2026-05-15
window_days: 0
quick_audit: true
data_sources:
  activitywatch: unconnected
  gmail: unconnected
  calendar: unconnected
  tasks: manual
  slack: unconnected
agent: claude-code
language: pl
goal_anchor: <workflow_context.goal>
---
```

Sections:
1. **Kontekst** — copy from intake
2. **Summary** — two sentences max, honest about the no-data limitation
3. **Patterns** — based on role + tasks.md only. Preface with: "*Wzorce wywnioskowane z opisu roli i ręcznie podanych zadań — bez danych telemetrycznych.*"
4. **Automation recommendations** — 3-5 concrete, actionable recommendations tied to `time_drains` and `tasks.md`
5. **Not worth automating** — same rules as full audit
6. **User-proposed automations** — ask the user "A co TY byś zautomatyzował?" and append (same as `audit.md` Step 6)
7. **Data sources used this run** — table showing all sources as `unconnected` or `manual`

## Step 5 — present and close

Print the compact summary:

```
Szybki audit gotowy — zapisany do ~/.flowhunt/audits/2026-05-15/audit.md

To był audyt BEZ danych z maila / kalendarza / Slacka. Rekomendacje opierają
się na Twoim opisie roli i ręcznie podanych zadaniach.

Top 3 do zautomatyzowania:
1. <first>
2. <second>
3. <third>

Jeśli chcesz dokładniejszy audyt z danymi z Twoich narzędzi:
  → odpal `flowhunt setup` i podłącz Gmail, Calendar, Slack, ActivityWatch
```

Then ask:
> Chcesz żebym teraz przeprowadził pełny setup z podłączeniem źródeł? Zajmie ~5 minut.

Or offer to build the first recommendation.

## Rules

1. **Never invent telemetry.** If you don't have ActivityWatch data, do not write "You spend 3h/day in Gmail."
2. **Role-based inference is allowed** but must be labeled as such.
3. **Same quality bar.** Recommendations must still be specific, actionable, and cross-checked against `sacred` and `failed_attempts`.
4. **Same append workflow.** Always ask "what would YOU automate?" and append to the file.
5. **Works without config.json.** This is the entry point for new users; do not require prior setup.
