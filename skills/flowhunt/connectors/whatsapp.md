# WhatsApp connector — ADVANCED, with disclaimer

## Read this first

**WhatsApp has no officially supported path for personal accounts.** Meta only provides an API for WhatsApp Business — which requires a dedicated phone number, Business verification, and (depending on volume) an upfront fee to Meta. If the user is running a business on WhatsApp Business API, that's a different story and they probably have internal tooling already.

For **personal WhatsApp** (the 99% case), the only OSS path is `lharries/whatsapp-mcp`, which uses `whatsmeow` — a reverse-engineered Go library that speaks WhatsApp's Web protocol by pairing as a linked device. It is stable and widely used (the same library powers `matrix-appservice-whatsapp`), but:

- **It's technically unofficial.** Meta can detect pairing from unusual clients and ban the account. This rarely happens for normal usage but it is not zero risk.
- **It's heavier to install** — Go toolchain + Python + `uv`, QR pairing via a linked-device scan, local SQLite sync that takes a few minutes on first run.
- **Personal privacy.** WhatsApp message history is often deeply personal. Think twice before letting an AI agent ingest it.

Tell the user explicitly before starting: "To jest zaawansowana ścieżka. WhatsApp nie ma oficjalnego API dla prywatnych kont. Biblioteka którą użyjemy jest stabilna i używana w produkcji, ale Meta teoretycznie może zbanować konto (rzadko się zdarza). Jeszcze chcesz iść dalej?"

Only proceed if the user explicitly confirms after hearing this.

---

## lharries/whatsapp-mcp

**Repo:** https://github.com/lharries/whatsapp-mcp

**Architecture:**
1. A Go bridge (`whatsapp-bridge`) based on `whatsmeow` connects to WhatsApp Web and syncs messages to a local SQLite file.
2. A Python MCP server (`whatsapp-mcp-server`) reads the SQLite file and exposes MCP tools: search messages, list contacts, download media.

**Prereqs:**
- Go 1.21+
- Python 3.11+
- `uv` (`brew install uv`)
- FFmpeg (for voice message transcription, optional)

### Step 1 — clone + run the bridge

```bash
git clone https://github.com/lharries/whatsapp-mcp.git ~/.flowhunt/whatsapp-mcp
cd ~/.flowhunt/whatsapp-mcp/whatsapp-bridge
go run main.go
```

On first run, the bridge prints a QR code to the terminal. The user opens WhatsApp on their phone → Settings → Linked Devices → Link a Device → scan the QR code. Pairing is instant. The bridge then syncs the last ~30 days of messages to `~/.flowhunt/whatsapp-mcp/whatsapp-bridge/store/messages.db`. Initial sync takes 2-10 minutes depending on message volume.

Leave the bridge running in a separate terminal (or as a LaunchAgent). If the bridge is not running, the MCP server has stale data.

### Step 2 — MCP config

For Claude Code (`~/.claude.json`):

```json
{
  "mcpServers": {
    "flowhunt-whatsapp": {
      "command": "uvx",
      "args": [
        "--from", "mcp-whatsapp-server",
        "mcp-whatsapp-server", "stdio"
      ],
      "env": {
        "WHATSAPP_MESSAGES_DB_PATH": "/Users/USERNAME/.flowhunt/whatsapp-mcp/whatsapp-bridge/store/messages.db"
      }
    }
  }
}
```

Replace `USERNAME` with the actual username. Show the user the exact block, have them paste it themselves.

For OpenCode (`~/.config/opencode/opencode.json`) — same shape under `mcp` key with `"type": "local"`.

For Codex (`~/.codex/config.toml`) — same shape with `[mcp_servers.flowhunt-whatsapp]`.

For Gemini:
```bash
gemini mcp add whatsapp stdio -- uvx --from mcp-whatsapp-server mcp-whatsapp-server stdio
```
plus env var separately.

### Step 3 — restart agent, verify

List recent contacts or search messages. If results come back, it works.

---

## What FlowHunt reads from WhatsApp

Strictly metadata + lightweight previews:
- Contact list (name + phone, group chats with member count)
- Message counts per contact in the last 30 days
- Top 15 contacts by volume
- Optional: first 80 chars of the top 10 messages the user sent (topic inference)
- NO full conversation history, NO media, NO voice message transcription unless the user explicitly asks

This deliberate scope reduces both the privacy blast radius and the audit prompt context size.

---

## When the account gets linked-device-limited

WhatsApp limits linked devices to 4 simultaneous. If the user runs out, the bridge fails to pair. Tell them: "Unlink an unused linked device in WhatsApp phone app → Settings → Linked Devices → tap the oldest → Log Out."

## When the account gets banned

Rare, but happens. The recovery path is: contact WhatsApp support, wait 24-72h, start over. FlowHunt is not going to help you argue with Meta. Make sure the user understood this risk before starting.

## Alternative: Kapso (Business API only)

If the user has WhatsApp Business API access (Meta Cloud API), the Kapso-style hosted MCP path exists but is out of scope for FlowHunt v1. For business users with existing Cloud API setup, let them know they can bring their own Cloud API tooling and point the audit at exports.
