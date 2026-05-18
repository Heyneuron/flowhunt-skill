# FlowHunt dry-run — preview collected data before analysis

Trigger phrases: `flowhunt dry-run`, `preview audit data`, `show me what you collected`, `co zebrałeś przed audytem`.

A dry-run performs Steps 0–2 of the full audit (precheck + data collection + raw dumps) but **stops before analysis**. It presents the user with a structured preview of what was collected, lets them confirm or object, and then offers to continue to full analysis or abort.

This is useful when:
- The user is privacy-sensitive and wants to see exactly what data will be fed into the LLM before analysis
- A connector is new and the user wants to verify it collected correctly
- The user wants to sanity-check ActivityWatch coverage ("did it actually capture my browser?")

## Procedure

### Step 1 — run collection exactly like audit

Follow `audit-precheck.md` and `audit-collect.md` verbatim. Do everything: health checks, read `workflow_context`, collect ActivityWatch, Gmail, Calendar, Tasks, Slack, messaging. Dump all raw files to `~/.flowhunt/audits/${TODAY}/raw/` just like a real audit.

**Do NOT run `audit-output.md` analysis yet.**

### Step 2 — produce the preview

After collection completes, print a compact structured summary in chat. Do NOT paste full JSON — summarize counts and a few sample items per source:

```
=== FlowHunt dry-run preview ===

ActivityWatch: 847 window events / 30 days, top app: VS Code (32h), browser watcher: YES ✅
Gmail: 142 threads, 23 with labels, top sender domains: github.com, linear.app
Calendar: 31 events, 4 recurring (weekly 1:1, daily standup)
Tasks (Notion): 18 open, 7 completed last 30d, recurring: "weekly report"
Slack: 12 channels, 87 user messages collected
Notion docs (extended): 5 recently edited pages — "SOP: onboarding", "Meeting notes: Q2 planning"

Raw dumps saved to: ~/.flowhunt/audits/2026-05-15/raw/
Total data footprint: ~<X> KB
```

For each source, show:
- **Count** of items collected
- **Top 1–2 examples** (app names, subject lines, event titles — whatever is most representative)
- **Coverage indicator** — e.g. "30 days ✅" or "only 3 days ⚠️ thin data"
- **Any errors** — if a source failed, show the error summary (not full stack trace)

### Step 3 — user confirmation

Ask:

> To wygląda OK? Jeśli tak — odpalam pełną analizę i zapiszę raport. Jeśli coś jest nie tak (np. za dużo danych z prywatnego Gmaila, brak ActivityWatch, zły zakres Slacka) — powiedz, poprawię zanim przejdziemy do analizy.

Wait for user response:

- **"OK" / "tak" / "continue"** → proceed to `audit-output.md` Step 3 (analysis). The raw data is already on disk, so analysis proceeds immediately. Write the final `audit.md` as usual.
- **"Too much" / "remove X" / "stop"** → abort. Offer `flowhunt config` to disconnect the offending source, or delete the raw files if the user wants. Do NOT run analysis.
- **"Show me more" / "pełne dane"** → dump a specific raw file in chat (e.g. `cat ~/.flowhunt/audits/2026-05-15/raw/gmail.json | head -n 50`). Let the user inspect. Then return to Step 3 confirmation.

### Step 4 — if continuing to full audit

Set a flag in the current session that this run started as `dry_run: true`. When writing `audit.md` frontmatter, include:

```yaml
---
dry_run: true
---
```

This lets future audits know that this report was preceded by a data-preview step.

## Differences from full audit

| | Dry-run | Full audit |
|---|---|---|
| Data collection | ✅ Full | ✅ Full |
| Raw dumps to disk | ✅ Yes | ✅ Yes |
| LLM analysis | ❌ No | ✅ Yes |
| Report written | ❌ No | ✅ Yes |
| User feedback question | ❌ No | ✅ Yes |
| Time | ~1–2 min | ~3–5 min |

## Edge cases

- **Collection fails mid-way:** Same rule as `audit-collect.md` — retry once, write `{"error":...}` to raw, continue. The dry-run preview shows which sources failed.
- **No data at all:** If every source is unconnected or failed, the preview says "No data collected — all sources unconnected or errored. Run `flowhunt setup` to connect sources." Offer `flowhunt quick-audit` as fallback.
- **User runs dry-run twice same day:** Overwrite the same `${TODAY}` folder. This is idempotent — the second dry-run replaces the first.
