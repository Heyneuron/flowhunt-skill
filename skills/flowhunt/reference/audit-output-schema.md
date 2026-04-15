# Audit output schema

The exact structure of `~/.flowhunt/audits/YYYY-MM-DD.md`. Follow this precisely. It is read both by the user and by the agent on future audits (for comparison + progress tracking).

## Full template

```markdown
---
date: 2026-04-15
window_days: 30
data_sources:
  activitywatch: ok
  gmail: ok | unconnected | error:<msg>
  calendar: ok | unconnected | error:<msg>
  slack: ok | unconnected | error:<msg>
  imessage: ok | unconnected | skipped
  whatsapp: ok | unconnected | skipped
agent: claude-code | codex | opencode | gemini | unknown
language: pl | en | ...
---

# FlowHunt audit — 2026-04-15

## Summary

<Two sentences max. #1 thing to automate first and why. If data is thin, say so here.>

**Estimated time saved:** <one short string, e.g. "4-6h / week">

## Patterns

- <pattern 1 — specific, tied to numbers from the data>
- <pattern 2>
- <pattern 3>
- ...

## Automation recommendations

### 1. <one-line title of the #1 thing to automate>

- **What:** <one sentence describing the specific thing to automate>
- **How:** <one sentence describing the concrete tool / integration / approach>
- **Estimated saved:** <hours per week>

### 2. <second title>

- **What:** ...
- **How:** ...
- **Estimated saved:** ...

### 3. <third title>

...

<Continue for as many recommendations as the data supports. 3-6 is typical.>

## Not worth automating

- <thing 1 — one line why not>
- <thing 2>
- ...

## Data sources used this run

| Source | Status | Volume |
|---|---|---|
| ActivityWatch | ok | <X days, Y top entries> |
| Gmail | ok/unconnected | <N messages scanned> |
| Google Calendar | ok/unconnected | <N events scanned> |
| Slack | ok/unconnected | <N channels, N messages> |
| iMessage | skipped | - |
| WhatsApp | skipped | - |

## Change since last audit

<If a previous audit exists in ~/.flowhunt/audits/, add this section. Otherwise omit.>

- Recommendation #1 from previous audit: **built / in progress / abandoned / still recommended**
- New patterns since <previous_date>: ...
- Estimated time saved delta: <+/- Xh>
```

## Rules for writing the file

1. **Frontmatter is mandatory.** The next audit run reads it to understand what data was available last time. Never skip it.
2. **Section order is fixed.** Summary → Patterns → Recommendations → Not worth → Data sources → Change since last. Do not reorder, do not merge sections.
3. **Recommendations numbered in priority order.** #1 is the single most impactful thing to automate first. If you cannot defend that ordering in the Summary, the ordering is wrong.
4. **"Estimated saved" is honest.** If you cannot put a number on it, do not put one. Write "hard to estimate — depends on how often X happens" and move on.
5. **Data sources table is always present** even when only ActivityWatch was available. It communicates the shape of the audit transparently.
6. **"Change since last audit" is only included when a previous audit file exists.** Otherwise omit the section entirely — do not write "no previous audit".
7. **Language matches the user's language.** This file is a user-facing artifact, not an English-only log.

## Example (minimal, ActivityWatch only, thin data)

```markdown
---
date: 2026-04-15
window_days: 30
data_sources:
  activitywatch: ok
  gmail: unconnected
  calendar: unconnected
  slack: unconnected
  imessage: skipped
  whatsapp: skipped
agent: claude-code
language: pl
---

# FlowHunt audit — 2026-04-15

## Summary

Dane są cienkie — tylko 5 dni ActivityWatch, brak podpiętego Gmaila i Slacka.
Najpilniejsze: uruchom audit ponownie za 10 dni, a tymczasem podłącz Gmail
(najsilniejszy sygnał w twoim stacku skoro spędzasz 40% czasu w Gmailu w Brave).

**Estimated time saved:** depends on connectors — re-run after 14 days

## Patterns

- 42% czasu aktywnego spędzasz w przeglądarce, z czego ~18% to Gmail (tytuł "Inbox - Gmail")
- 3 okna Warp otwarte równolegle przez >2h dziennie, tytuły sugerują pracę w Claude Code
- ...

## Automation recommendations

### 1. Podłącz Gmail do flowhunt

- **What:** Włącz konektor Gmail w Claude, bo bez niego audit nie widzi twojej głównej osi pracy.
- **How:** Otwórz https://claude.ai/settings/connectors i kliknij Connect przy Gmail.
- **Estimated saved:** enables the rest of the audit

### 2. ...

## Not worth automating

- ...

## Data sources used this run

| Source | Status | Volume |
|---|---|---|
| ActivityWatch | ok | 5 days, 87 entries |
| Gmail | unconnected | - |
| Google Calendar | unconnected | - |
| Slack | unconnected | - |
| iMessage | skipped | - |
| WhatsApp | skipped | - |
```
