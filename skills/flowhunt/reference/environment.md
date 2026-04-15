# Agent environment reference

You (the agent) need to know which agent harness you are running inside, and which environment constraints apply. This page is the single source of truth — no helper scripts, just facts you read and act on.

## Detecting which agent you are

Run this in bash (or the equivalent in your environment):

```bash
env | grep -E '^(CLAUDECODE|CODEX_THREAD_ID|OPENCODE_CLIENT|GEMINI_CLI)=' | cut -d= -f1
```

Match the result against this table. Precedence is top to bottom — if multiple markers are set (e.g. Codex started inside a Claude Code shell), take the innermost agent.

| Env var present | Agent | Notes |
|---|---|---|
| `CODEX_THREAD_ID` | `codex` | Set per session by `codex-rs/config/src/shell_environment.rs`. Codex clears the parent env and re-populates a strict allowlist, so other markers do not survive into a Codex shell. |
| `CLAUDECODE` | `claude-code` | Value is always `1`. Source: docs at `code.claude.com/docs/en/env-vars`. |
| `GEMINI_CLI` | `gemini` | Value is always `1`. Source: `gemini-cli-core/services/shellExecutionService.js` (`GEMINI_CLI_IDENTIFICATION_ENV_VAR`). |
| `OPENCODE_CLIENT` | `opencode` | Value is always `1`. |
| none | `unknown` | Proceed with universal fallbacks (OSS MCPs, IMAP). |

Store the result. Every later branch in `setup.md` / `audit.md` depends on it.

## Sandbox constraints per agent

When you know which agent you are, you know what the shell can and cannot do. This is critical — do not waste time fighting the sandbox; adapt.

### `codex`

Codex CLI on macOS runs all tool calls through a **seatbelt sandbox** by default (`--full-auto` uses `workspace-write` policy). Confirmed blocked operations in `workspace-write`:

- `open -a <App>` — launching GUI applications is refused by the seatbelt policy. Codex wraps the failure as `SandboxDenied`, and stdout is moved to stderr in the error envelope.
- `nohup <cmd> &` — the `nice` syscall is refused (`zsh:1: nice(5) failed: operation not permitted`).
- Binding network sockets on arbitrary ports (`python3 -m http.server 5600`, `aw-server`) — refused with `PermissionError: [Errno 1] Operation not permitted`.
- Writing to `~/Library/Logs/`, `~/Library/Application Support/` outside the workspace root — refused.
- `open` with http/https URLs — macOS LaunchServices rejects the URL scheme from sandboxed shells with `kLSExecutableIncorrectFormat`.

**Corollary:** when running inside Codex, **never attempt to launch ActivityWatch or open a browser programmatically**. Always defer to the user. For AW: instruct the user to click the tray icon. For browser URLs: print the URL prominently and ask the user to open it themselves.

Codex does allow:
- Reading files in the workspace and in standard user config paths
- Running `curl` to localhost endpoints (unrestricted outbound to `127.0.0.1`)
- Running `jq`, `grep`, `python` (for short non-binding scripts), `git`, `npm`, `node`, `uvx`, most Unix tools
- Writing files inside the workspace directory
- Reading from `~/.codex/config.toml`, `~/.agents/skills/`, `~/.claude/skills/`

That gives you enough to query AW (curl to localhost:5600 works) and to read/write config files (opencode.json, config.toml, etc.), but not to launch apps or bind ports.

If the user needs something that requires escaping the sandbox (e.g. installing Homebrew, running `brew install`, launching ActivityWatch the first time), tell them to run the command themselves in a separate terminal and come back.

### `claude-code`

Claude Code's bash tool has per-command permissions controlled by the user's `settings.json`. By default `curl`, `open`, `brew`, most Unix tools work. GUI launching via `open -a` typically works on macOS. No systematic seatbelt-style denial.

If a command you want to run is not on the user's allowlist, you will get a permission prompt; let the user approve or deny, don't try to work around it.

### `gemini`

Gemini CLI inherits the user's shell environment without a hard sandbox by default. Same expectations as Claude Code. You can `open -a` on macOS, launch background processes, bind ports.

### `opencode`

OpenCode runs bash via its built-in tool with user-controlled permissions (`permission.bash` in `opencode.json`). Similar to Claude Code. No default sandbox.

### `unknown`

Assume minimum: curl to localhost works, file reads work, nothing else is guaranteed. Degrade gracefully: ask the user to run anything complex themselves.

## Rule of thumb

Before running any Bash command that could touch the sandbox (GUI app launch, port binding, system directory write), **check the agent**. If `codex`, skip the attempt and ask the user. If anything else, try it.

This is not a quirk — it is the permanent shape of the constraint. Codex's sandbox is not going to change. Plan around it.
