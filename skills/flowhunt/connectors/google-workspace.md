# Google Workspace connector (Gmail + Calendar)

Every agent has a different path to Gmail and Calendar. Zero of them require a Google Cloud project. Pick the branch matching the agent detected by `scripts/detect-agent.sh` and follow it exactly.

All paths below give the agent **read-only** access to Gmail metadata (headers, subjects, dates, snippets) and Calendar events — never message bodies and never write access. For FlowHunt we do not need either.

---

## Claude Code (and Claude Desktop)

**Source of truth:** https://support.claude.com/en/articles/10166901-use-google-workspace-connectors

### Flow

1. Open the connector settings page for the user:
   ```bash
   open "https://claude.ai/settings/connectors"   # macOS
   xdg-open "https://claude.ai/settings/connectors"  # Linux
   start "https://claude.ai/settings/connectors"   # Windows
   ```
2. Tell the user: "Kliknij **Connect** obok Gmail. Zaloguj się w Google, przewróć na wszystkie zgody (Anthropic prosi o read-only). Zrób to samo dla Google Calendar. Potem wróć tutaj i napisz 'gotowe'."
3. When they confirm, verify by calling a Gmail tool:
   ```
   mcp__claude_ai_Gmail__gmail_get_profile
   ```
   If it returns the user's email address, Gmail is wired. Do the same for `mcp__claude_ai_Google_Calendar__list_calendars` for Calendar.
4. If verification fails, the connector did not propagate. Possible reasons:
   - User is in a Team/Enterprise workspace where the Owner hasn't enabled connectors org-wide. Tell the user: "Twój workspace wymaga zgody Ownera. Albo poproś kogoś kto ma admina, albo podłącz się w osobistym koncie Claude."
   - User is on Claude Code version older than v2.1.46 (before connector propagation). Tell them to update: `npm install -g @anthropic-ai/claude-code@latest`.

### Permissions hardening (optional but recommended)

In the connector UI the user can restrict each tool. Set these to "Always allow":
- `gmail_search_messages`
- `gmail_read_message` (only if you want snippets)
- `gmail_list_labels`
- `gmail_get_profile`

And set these to "Never allow":
- `gmail_create_draft`
- `gmail_send_message` (if exposed)
- Any calendar write tools

FlowHunt only reads; never writes.

---

## Codex CLI

**Source of truth:** https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan and https://developers.openai.com/codex/plugins

### Flow

1. Confirm the user is signed into Codex with a ChatGPT account (not an API key):
   ```bash
   codex auth status
   ```
   If they're on an API-key plan, fall through to the **Universal fallback — IMAP + App Password** section below. The one-click path requires the ChatGPT app ecosystem.
2. If signed in with ChatGPT Plus/Business: open the apps page:
   ```bash
   open "https://chatgpt.com/apps"
   ```
   Tell the user: "Włącz Gmail i Google Calendar w tej liście. OAuth zrobi się w przeglądarce, jeden klik."
3. Alternatively, inside Codex CLI in interactive mode: type `/apps` to see the status and enable apps from there.
4. Verify: inside the Codex composer the user types `$` — the app picker should list Gmail. If it does, it's wired.
5. OpenAI confirms: "Controls apply to all surfaces (ChatGPT web, Atlas, mobile, and Codex)." Apps enabled on chatgpt.com propagate to Codex CLI automatically.

### Codex Plugins directory (alternative zero-config path)

Inside Codex CLI interactive session:
```
/plugins
```
Opens the plugins marketplace in the browser. The curated `gmail@openai-curated` and `slack@openai-curated` plugins use the ChatGPT connector OAuth under the hood — same result, different UX.

---

## Gemini CLI

**Source of truth:** https://github.com/gemini-cli-extensions/workspace

This is the cleanest path of all four agents. Google ships its own Workspace extension that reuses the user's existing Gemini OAuth token (the `oauth-personal` mode every Gemini CLI user already has after first login).

### Flow

```bash
gemini extensions install https://github.com/gemini-cli-extensions/workspace
```

That's it. One command. No second browser flow, no API keys, no consent screen beyond what Gemini already asked for at first install.

Verify:

```bash
gemini extensions list | grep workspace
```

And inside Gemini CLI:

```
/gmail/search query:"newer_than:30d" max_results:500
```

Should return a list of message metadata. If it does, Gmail + Calendar + Drive + Docs + Sheets are all wired (the extension bundles the whole Workspace surface).

---

## OpenCode — IMAP + App Password

OpenCode has no native OAuth broker for Google. We deliberately do NOT use SaaS MCP brokers (Composio et al) because they are startups that may disappear. The durable path is IMAP + a Gmail App Password. IMAP is an IETF RFC from 1988 and Google's App Passwords feature is a first-party Google account security feature tightly coupled to 2FA. Neither is going anywhere.

**Caveat:** this path gives you Gmail only. Calendar does not have a corresponding "generic protocol + app password" story that works for Google Calendar without OAuth. For OpenCode users, **Calendar is skipped in FlowHunt**. Tell them that explicitly in setup.

### Step 1 — get a Gmail App Password

1. The user must have 2-Step Verification enabled. Open:
   ```bash
   open "https://myaccount.google.com/security"
   ```
   Guide them to "How you sign in to Google" → "2-Step Verification" → enable if off.
2. Once 2FA is on, open the App Passwords page directly:
   ```bash
   open "https://myaccount.google.com/apppasswords"
   ```
3. In the "App name" field: type `opencode-flowhunt`. Click Create.
4. Google shows a 16-character password once, format `xxxx xxxx xxxx xxxx`. The user copies it. If lost, they have to revoke and regenerate.

### Step 2 — install the IMAP MCP server

Requires `uv` (https://astral.sh/uv):

```bash
# macOS
brew install uv

# Linux / anywhere
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Step 3 — add to `~/.config/opencode/opencode.json`

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "flowhunt-email": {
      "type": "local",
      "command": ["uvx", "mcp-email-server@latest", "stdio"],
      "environment": {
        "MCP_EMAIL_SERVER_EMAIL_ADDRESS": "user@gmail.com",
        "MCP_EMAIL_SERVER_PASSWORD": "xxxx xxxx xxxx xxxx",
        "MCP_EMAIL_SERVER_IMAP_HOST": "imap.gmail.com",
        "MCP_EMAIL_SERVER_IMAP_PORT": "993",
        "MCP_EMAIL_SERVER_SMTP_HOST": "smtp.gmail.com",
        "MCP_EMAIL_SERVER_SMTP_PORT": "465"
      },
      "enabled": true
    }
  }
}
```

Tell the user to edit this file themselves (DO NOT write secrets for them unless they insist). Show them the exact block to paste and the two fields to replace (`user@gmail.com`, the password).

### Step 4 — restart OpenCode and verify

```bash
opencode mcp list
```

Should show `flowhunt-email` as enabled. Then in an OpenCode session, ask the agent to search emails from the last 30 days. If results come back, it works.

---

## Universal fallback (any agent, any situation)

If every path above failed for whatever reason, the fallback is the same as the OpenCode path: **IMAP + Gmail App Password** via any local MCP the agent supports.

For Claude Code / Claude Desktop: add to `~/.claude.json` under `mcpServers`:
```json
{
  "mcpServers": {
    "flowhunt-email": {
      "command": "uvx",
      "args": ["mcp-email-server@latest", "stdio"],
      "env": {
        "MCP_EMAIL_SERVER_EMAIL_ADDRESS": "user@gmail.com",
        "MCP_EMAIL_SERVER_PASSWORD": "xxxx xxxx xxxx xxxx",
        "MCP_EMAIL_SERVER_IMAP_HOST": "imap.gmail.com",
        "MCP_EMAIL_SERVER_IMAP_PORT": "993",
        "MCP_EMAIL_SERVER_SMTP_HOST": "smtp.gmail.com",
        "MCP_EMAIL_SERVER_SMTP_PORT": "465"
      }
    }
  }
}
```

For Codex: the equivalent `[mcp_servers.flowhunt-email]` block in `~/.codex/config.toml`.

For Gemini: `gemini mcp add flowhunt-email stdio -- uvx mcp-email-server@latest stdio` then set env vars separately.

Use this fallback only after you have tried the agent's native path and it failed. The native path is always better — it's one click and uses OAuth with full scopes.
