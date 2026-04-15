#!/usr/bin/env bash
# Emit the name of the AI agent this shell is running inside.
# Used by setup.md and audit.md to branch per-agent instructions.
#
# Detection is based on environment variables each agent injects into its
# spawned child shells. Verified April 2026 against each agent's source:
#
#   Claude Code -> CLAUDECODE=1
#     docs: code.claude.com/docs/en/env-vars
#
#   Codex CLI   -> CODEX_THREAD_ID=<uuid>
#     source: codex-rs/config/src/shell_environment.rs
#     ("pub const CODEX_THREAD_ID_ENV_VAR: &str = \"CODEX_THREAD_ID\";"
#      injected via env_map.insert in populate_env)
#     IMPORTANT: Codex clears the parent env and re-populates a minimal
#     allowlist (PATH, SHELL, TMPDIR, HOME, LANG, USER, ...) — so CODEX_HOME
#     does NOT propagate into child shells. CODEX_THREAD_ID is the only
#     Codex-specific variable guaranteed to appear inside a spawned process.
#
#   OpenCode    -> OPENCODE_CLIENT=1
#     docs: opencode.ai/docs
#
#   Gemini CLI  -> GEMINI_CLI=1
#     source: gemini-cli-core/services/shellExecutionService.js
#     (GEMINI_CLI_IDENTIFICATION_ENV_VAR = 'GEMINI_CLI', value '1')
#
# Precedence: if two markers are set (e.g. Codex launched from a Claude Code
# shell), return the innermost agent. The order below encodes that.

if [ -n "${CODEX_THREAD_ID:-}" ]; then
    echo "codex"
elif [ -n "${CLAUDECODE:-}" ]; then
    echo "claude-code"
elif [ -n "${GEMINI_CLI:-}" ]; then
    echo "gemini"
elif [ -n "${OPENCODE_CLIENT:-}" ]; then
    echo "opencode"
else
    echo "unknown"
fi
