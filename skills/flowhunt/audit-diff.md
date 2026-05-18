# FlowHunt audit diff — automated change detection

This module is called from `audit-output.md` Step 4 (before writing the final report) when at least one previous audit exists in `~/.flowhunt/audits/`. It produces a `## Changes since last audit` section that is inserted into the current audit markdown.

## When to run

Always check for previous audits after raw data collection completes. Look in `~/.flowhunt/audits/` for folders with dates earlier than `${TODAY}`. Pick the most recent one. If found, read its `audit.md` and generate the diff. If not found, skip silently.

## What to compare

Read the previous `audit.md` and extract:

1. **Patterns** — the bullet list under `## Patterns`
2. **Automation recommendations** — the bullet list under `## Automation recommendations`
3. **Not worth automating** — the bullet list under `## Not worth automating` (if present)
4. **Data sources used** — the list under `## Data sources used this run` (for context, not diffed)

## Diff algorithm (performed by you, the LLM)

Do not use `diff` CLI — read both files and reason about changes. Produce these sub-sections:

### New since last audit
- Recommendations that appear in the current audit but were NOT in the previous one
- Patterns that are newly detected
- Any newly connected data sources (e.g. "Slack added since last run")

### Resolved / improved
- Recommendations from the previous audit that are no longer needed because the user implemented them, OR whose underlying pattern has disappeared from the data
- Patterns that no longer appear (e.g. "Spotify 4h/day" dropped to 30 min)
- Be humble — if unsure whether something was resolved, phrase as "likely improved" or "no longer detected"

### Persistent
- Recommendations or patterns that appear in BOTH audits unchanged (or nearly unchanged)
- This is valuable — it tells the user what chronic issues keep surfacing

### Data quality delta
- Compare data source richness: did ActivityWatch go from 3 days → 30 days? Did Slack get connected? More calendar events? Note the improvement or regression.

## Output format

Append the diff as a new section in the current `audit.md`, inserted **after** `## Summary` and **before** `## Patterns`:

```markdown
## Changes since last audit

*Previous audit: 2026-04-01. Current: 2026-05-15.*

### New since last audit
- ...

### Resolved / improved
- ...

### Persistent
- ...

### Data quality delta
- ...
```

Keep each bullet to max two sentences. If a section has no items, write "(brak zmian w tej kategorii)" or "(no changes in this category)" depending on user language.

## Edge cases

- **First audit ever:** skip diff entirely. No section added.
- **Previous audit in different language:** translate your diff bullets to the language of the CURRENT audit.
- **Previous audit corrupted or unreadable:** skip diff, note in Summary: "(diff skipped — previous audit file unreadable)"
- **User renamed or moved audit folders:** check only `~/.flowhunt/audits/YYYY-MM-DD/audit.md`. If the user moved files outside this tree, that's unsupported.
- **Same-day re-run:** if the most recent previous audit is the same date as `${TODAY}`, diff against the second-most-recent to avoid comparing a half-written audit against itself.
