# FlowHunt diff-audit procedure

Trigger phrases: `flowhunt diff`, `porównaj z poprzednim audytem`, `co się zmieniło`, `diff audit`, `jak mi idzie`, `progress since last audit`.

Goal: compare the current audit (or the most recent one) with the previous audit to show the user what changed: new patterns, built/abandoned recommendations, shifting time allocation, new connectors added.

## When to use

- User asks "how am I doing since last time?"
- After running `flowhunt audit`, the user wants context on whether things improved.
- User wants to see if a recommendation they built actually saved time.

## Prerequisites

Requires **at least two audit folders** in `~/.flowhunt/audits/`:

```bash
ls -t ~/.flowhunt/audits/ | head -2
```

If fewer than 2 folders exist, print: "Mam tylko jeden audit — porównanie wymaga co najmniej dwóch. Odpal `flowhunt audit` jeszcze raz za jakiś czas."

## Procedure

### Step 0 — identify the two audits to compare

Default: compare the **most recent** audit with the **second most recent**.

```bash
AUDITS=($(ls -t ~/.flowhunt/audits/ | head -2))
CURRENT="${AUDITS[0]}"
PREVIOUS="${AUDITS[1]}"
```

If the user specifies dates (e.g. "porównaj 2026-05-01 z 2026-04-15"), use those instead.

Read both `audit.md` files into working memory.

Also read both `raw/intake.json` files to compare `workflow_context` changes (role change? goal change?).

### Step 1 — compute structural diffs

For each section of the audit, compare `CURRENT` vs `PREVIOUS`:

#### 1a. Data sources diff

| Source | Previous | Current | Change |
|---|---|---|---|
| ActivityWatch | 12 days | 35 days | +23 days of data |
| Gmail | connected | connected | no change |
| Slack | unconnected | connected | **new** |
| Task tracker | manual | Linear | **upgraded** |

#### 1b. Patterns diff

- **New patterns** (appear in Current but not in Previous)
- **Resolved patterns** (appear in Previous but not in Current) → "pattern disappeared, possibly automated or stopped happening"
- **Intensified patterns** (same pattern, higher volume/time)
- **Weakened patterns** (same pattern, lower volume/time)

#### 1c. Recommendations diff

For each recommendation from Previous, check Current:
- **Built** — user confirms they implemented it, or data shows the pattern disappeared
- **In progress** — pattern still exists but volume decreased
- **Abandoned** — pattern still exists at same volume, recommendation still valid
- **Still recommended** — no change

Also list **new recommendations** that appear in Current but not in Previous.

#### 1d. Time allocation diff (if ActivityWatch data exists in both)

Compare top apps/categories:
- "Gmail time dropped from 8h/week to 4h/week — likely your email triage automation is working"
- "Slack time increased from 3h to 7h/week — new pattern to investigate"

#### 1e. Workflow context diff

Compare `intake.json → workflow_context`:
- Role changed? → "Rola zmieniła się z X na Y — audyt musi teraz uwzględniać nowe priorytety"
- Goal changed? → "Cel zmienił się z X na Y — zalecenia zostały przeskalibrowane"
- New failed_attempts? → "Dodano nowe nieudane próby: X, Y — te ścieżki są teraz na blacklist"

### Step 2 — write the diff report

Create `~/.flowhunt/audits/${CURRENT}/diff-${PREVIOUS}.md`:

```markdown
# FlowHunt diff — ${CURRENT} vs ${PREVIOUS}

## Workflow context changes

- Rola: <prev> → <curr> (or "no change")
- Cel: <prev> → <curr> (or "no change")
- Nowe bóle: <list>
- Rozwiązane bóle: <list>

## Data sources evolution

<table>

## Patterns — what changed

### New patterns
- <pattern 1>
- ...

### Resolved patterns (good sign)
- <pattern 1> — possibly automated or stopped
- ...

### Intensified
- <pattern> — <prev Xh> → <curr Yh>

### Weakened
- <pattern> — <prev Xh> → <curr Yh>

## Recommendations — progress tracker

| # | Recommendation | Status | Notes |
|---|---|---|---|
| 1 | <title> | built / in progress / abandoned / still recommended | <why> |
| 2 | ... | ... | ... |

## Time allocation delta (ActivityWatch)

| App / Category | Previous | Current | Δ |
|---|---|---|---|
| Gmail | 8h | 4h | -4h ✅ |
| Slack | 3h | 7h | +4h ⚠️ |
| ... | ... | ... | ... |

## Summary

<2-3 sentences on the #1 takeaway>
```

### Step 3 — present inline

Print a compact summary:

```
Porównanie gotowe — zapisane do ~/.flowhunt/audits/${CURRENT}/diff-${PREVIOUS}.md

Co się zmieniło:
  Nowe wzorce: <N>
  Rozwiązane wzorce: <N>
  Zbudowane rekomendacje: <N>
  Wciąż otwarte: <N>

Top insight:
  <one sentence — e.g. "Spędzasz o 4h/tydz mniej w Gmailu odkąd wdrożyłeś
   triage automation. Slack wzrósł o 4h — to twój nowy #1 cel.">
```

### Step 4 — offer next actions

- "Chcesz żebym skupił się na tym co się nasiliło?"
- "Chcesz zaktualizować swój kontekst / cele? (flowhunt config)"
- "Chcesz nowy pełny audit?"

## Rules

1. **Honest deltas.** If a recommendation is "still recommended" for 3 audits in a row, say so — it's a signal the user hasn't acted, not a failure of the audit.
2. **Never invent progress.** If you don't know whether the user built a recommendation, mark it "unknown" rather than "built".
3. **Respect role changes.** If the user's role changed, do not compare old patterns as if the context stayed the same. A new role means new baseline.
4. **Quantify when possible.** "Less Gmail time" is weak. "Gmail dropped from 8h to 4h/week" is strong.
