# FlowHunt — agent conventions

This file governs how agents modify the FlowHunt skill. Read it before editing any file in this directory.

## Project structure

```
skills/flowhunt/
  SKILL.md                  # Entry point + command dispatch (all modes)
  setup.md                  # Onboarding procedure (interview, Steps 0–1)
  setup-activitywatch.md    # ActivityWatch install / launch / verification (Step 2)
  setup-connectors.md       # Email, Calendar, Tasks, Slack, Messaging (Steps 3–7)
  audit.md                  # Audit dispatch — routes to 3 sub-modules
  audit-precheck.md         # Health checks + workflow context reuse
  audit-collect.md          # Data collection from all sources + raw dumps
  audit-output.md           # Analysis, report writing, user feedback, next actions
  audit-diff.md             # Automated diff generation during audit (Step 3.5)
  diff-audit.md             # Standalone diff mode (user asks "co się zmieniło")
  dry-run.md                # Preview collected data before analysis
  status.md                 # Read-only health check
  quick-audit.md            # Interview-only audit, no connectors (~2 min)
  config.md                 # Edit workflow_context / connectors without full setup
  connectors/               # Per-source wiring instructions
    slack.md
    google-workspace.md
    task-trackers.md
    activitywatch.md
    messaging.md
  prompts/                  # LLM analysis prompts
    audit-system-prompt.md
  reference/                # Facts, schemas, API docs
    environment.md
    activitywatch-api.md
    audit-output-schema.md
    config-schema.md        # ~/.flowhunt/config.json schema
```

## Rules for editing

1. **No helper scripts.** FlowHunt is pure markdown instructions. Never add `.sh`, `.py`, or `.js` wrappers. Agents read the facts and construct Bash themselves.
2. **Never require API keys or GCP projects.** Every connector path must work without Google Cloud, Anthropic API keys, or OpenAI API keys.
3. **Maintain agent branching.** Any procedure touching shell, network, or GUI must branch on the detected agent (`claude-code`, `codex`, `gemini`, `opencode`, `unknown`). Codex sandbox constraints are documented in `reference/environment.md` — do not fight them.
4. **Keep Polish as the default template language.** The original skill targets Polish-speaking users. When adding new templates or prompts, write them in Polish first, English second. Other languages are handled by translation at runtime.
5. **One-command-per-line in sandboxed shells.** In Codex and similar restricted environments, never chain with `&&`. Run each command in its own Bash turn.
6. **Version the schema.** If you change `reference/config-schema.md` or `reference/audit-output-schema.md`, bump the `version` field in `SKILL.md` frontmatter and document the migration in `reference/config-schema.md`.
7. **Always dump raw.** Any audit or collection step must persist raw data to `~/.flowhunt/audits/YYYY-MM-DD/raw/` before analysis. Working memory is not a source of truth.
8. **Verify with real tool calls.** After every connector setup, the agent must make an actual tool call to confirm the connector works. Do not trust "the user said it works."

## Testing changes

Before declaring a change complete:

1. Read the modified file top-to-bottom to ensure no broken cross-references.
2. Check that any new file is referenced from `SKILL.md`.
3. Ensure the new procedure works without ActivityWatch (AW is optional).
4. Ensure the new procedure works without Gmail (universal fallback is IMAP + App Password).
