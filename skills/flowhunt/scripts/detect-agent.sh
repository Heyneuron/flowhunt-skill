#!/usr/bin/env bash
# Emit the name of the AI agent this shell is running inside.
# Used by setup.md and audit.md to branch per-agent instructions.
#
# Detection is based on environment variables each agent sets in child shells.
# Verified April 2026:
#   Claude Code  -> CLAUDECODE=1         (docs: code.claude.com/docs/en/env-vars)
#   Codex CLI    -> CODEX_HOME set       (docs: github.com/openai/codex/blob/main/docs/config.md)
#   OpenCode     -> OPENCODE_CLIENT=1    (docs: opencode.ai/docs)
#   Gemini CLI   -> GEMINI_CLI=1         (source: gemini-cli-core/services/shellExecutionService.js)
#
# Precedence note: if two env vars are set simultaneously (e.g. a user runs
# Codex inside a Claude Code shell for testing), we return the innermost
# likely-active one. The order below encodes that precedence.

if [ -n "${CLAUDECODE:-}" ]; then
    echo "claude-code"
elif [ -n "${GEMINI_CLI:-}" ]; then
    echo "gemini"
elif [ -n "${OPENCODE_CLIENT:-}" ]; then
    echo "opencode"
elif [ -n "${CODEX_HOME:-}" ]; then
    echo "codex"
else
    echo "unknown"
fi
