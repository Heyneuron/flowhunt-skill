# FlowHunt audit — analysis, output, and close

This module covers turning the collected raw data into the written audit report and closing the session.

## Step 3 — apply the audit prompt

Load `prompts/audit-system-prompt.md`. That is your system instructions for this task — read carefully. It specifies:

- Five sections: Patterns, Automation recommendations, Not worth automating, Estimated time saved, Summary
- Hard rules: focus only on automation, no productivity tips, max two sentences per bullet, no browser-tabs / RAM observations
- Language match to the user
- User's written ideas (task tracker tasks + `~/.flowhunt/tasks.md` + user-proposed automations from Step 5) = highest priority input

Your analysis input is the union of, in priority order:

1. **`workflow_context` from Step 0.5** — the user's stated role, top time drains, failed attempts, sacred areas, and goal. This is the highest-priority signal. Every recommendation must be cross-checked against it (do not recommend a `failed_attempts` path, do not touch a `sacred` area, prioritize anything matching `time_drains`, optimize for `goal`).
2. ActivityWatch top-100 records from Step 1
3. Every messaging/workspace/task bundle you successfully collected in Step 2
4. Any previous audit markdown in `~/.flowhunt/audits/` from the last 30 days — read the most recent one so you can note changes since the last audit (optional but high value)

**Do the analysis yourself.** You are the LLM. Do not try to call an external API. Whatever model the user is running you with produces the output.

## Step 3.5 — generate diff against previous audit (if any)

After analysis is complete but before writing the final file, check `~/.flowhunt/audits/` for previous audits. If one exists, load `audit-diff.md` and generate the `## Changes since last audit` section. This section is inserted into the current report after `## Summary`.

If no previous audit exists, skip silently.

## Step 4 — write the output file

Create `~/.flowhunt/audits/${TODAY}/audit.md` using the exact structure defined in `reference/audit-output-schema.md`. Frontmatter is mandatory — the next audit reads it to understand what data was available last time.

At this point the audit has 5 sections (Summary / Patterns / Recommendations / Not worth / Data sources) but NO user-proposed automations yet. That section is added in Step 6 after you ask the user.

## Step 5 — present top findings inline

Print a compact summary in the chat:

```
Audit gotowy — zapisane do ~/.flowhunt/audits/2026-04-15/audit.md
Raw data w ~/.flowhunt/audits/2026-04-15/raw/ (do re-analizy albo eksportu)

Top 3 do zautomatyzowania:
1. <first recommendation — one sentence what + one sentence how>
2. <second recommendation>
3. <third recommendation>

Estimated time saved: <short string from section 4>
```

Do NOT paste the whole audit in chat. The file is the artifact; chat is the teaser.

## Step 6 — ask the user for their own automation ideas

This is the key question — do not skip it. After presenting your own findings, ask:

> **A co TY byś zautomatyzował?** Jakie rzeczy zjadają ci dużo czasu ręcznie, o których z perspektywy danych w audycie może nie widać? Masz coś co ci zajmuje 2h tygodniowo i uważasz że powinno być jednym kliknięciem? Wrzuć luźno, nawet krótko — dopiszę do audytu jako najwyższy priorytet, bo twoje własne obserwacje o własnym czasie są ważniejsze niż moje wnioski z metryk.

Wait for the user to answer. They may:
- Give a list of specific tasks → write each as a proposed automation, append a section `## User-proposed automations` to `audit.md` with each item + whatever "how to build it" suggestion you can offer
- Say "nie wiem" / "nic mi nie przychodzi" → write a one-liner section `## User-proposed automations` with "(nic nie zgłoszono w tej sesji — zaproponuj mi przy następnym audycie)"
- Give a general direction (e.g. "cokolwiek co mi oszczędzi 2h na mailach") → try to narrow down with one follow-up question; if still vague, record what they said verbatim and move on

**Append — do not rewrite the file.** The first five sections stay exactly as you wrote them in Step 4. You add `## User-proposed automations` after section 5 and before `## Data sources used this run`. Or, if cleaner, at the bottom.

Save the user's raw answers to `raw/user-proposed.md` in the audit folder so re-analysis has them.

## Step 7 — feedback CTA

After presenting findings and user-proposed automations, show the feedback link. This is mandatory — never skip it:

```
Dzięki za audyt! Mam prośbę — wypełnij 2-minutowy feedback:
👉 https://flowhunt.heyneuron.com/feedback

W zamian wyślę ci gotową listę automatyzacji dopasowaną do twojego
stacku (wartość $29) — konkretne narzędzia, integracje i kroki
wdrożenia. Możesz ją potem wrzucić do agenta i porozmawiać z nim
o implementacji.
```

## Step 8 — offer next actions

Close with two concrete next moves:

- "Chcesz żebym zbudował pierwszą rekomendację? Mogę otworzyć osobną sesję pracy nad tym."
- "Chcesz porównanie z poprzednim audytem?"

If the user asks for comparison, load `diff-audit.md` and follow its procedure.

The user can decline both and close the session — fine. Asking keeps the loop going from report to actual automation built.

## Rules specific to audit output

1. **Thin data warning.** No ActivityWatch, less than 7 days of AW data, or less than 20 emails / 20 calendar events / 10 tasks → say so in the Summary section and recommend re-running after more data accrues. But never block the audit — always produce the best report you can with available data.
2. **Never invent data.** If a source is unconnected, it is unconnected. Do not guess.
3. **Respect user-written tasks and user-proposed automations.** These are the two highest-priority inputs. Surface them in Recommendations section before anything you only detected from raw telemetry.
4. **Always dump raw.** If a collection step succeeds, its output goes to `raw/<source>.json` in the audit folder before you move on. Do not rely on working memory as the only copy.
5. **Language match.** File is in the user's language. Default English when unclear.
6. **No API keys, no provider switching.** You are the LLM.
7. **Adapt to your sandbox.** If you are in `codex` with a restrictive sandbox (network blocked — see `reference/environment.md`), bail out early with the three-options message, do not attempt curl/MCP calls that will hang.
