#!/usr/bin/env bash
# Try to start ActivityWatch on the current OS. Always print a status line
# so the agent can make a decision even when nothing worked.
#
# Output (one line):
#   LAUNCHED                 - we believe the launch command succeeded
#   ALREADY_RUNNING          - server was already responding before we tried
#   UNSUPPORTED_OS           - don't know how to start on this platform
#   FAILED:<short reason>    - launch attempt failed; agent should fall back
#                              to asking the user to start it manually
#
# Exit code: 0 on LAUNCHED or ALREADY_RUNNING, 1 otherwise.
#
# This script does NOT wait for the server to come up. The caller should
# sleep 8-12 seconds after LAUNCHED and re-run aw-check.sh.

AW_BASE="http://localhost:5600/api/0"

# Short-circuit: already running?
if curl -fsS --max-time 2 "$AW_BASE/info" > /dev/null 2>&1; then
    echo "ALREADY_RUNNING"
    exit 0
fi

os="$(uname -s)"

case "$os" in
    Darwin)
        # Prefer the .app bundle if installed via Homebrew cask.
        if [ -d "/Applications/ActivityWatch.app" ]; then
            if open -g -a "ActivityWatch" 2>/dev/null; then
                echo "LAUNCHED"
                exit 0
            fi
            # -g may fail in sandboxed shells; try without it.
            if open -a "ActivityWatch" 2>/dev/null; then
                echo "LAUNCHED"
                exit 0
            fi
            echo "FAILED:open_refused_by_sandbox"
            exit 1
        fi
        # Fallback: look for aw-qt on PATH (non-cask install)
        if command -v aw-qt > /dev/null 2>&1; then
            nohup aw-qt > /dev/null 2>&1 &
            disown 2>/dev/null || true
            echo "LAUNCHED"
            exit 0
        fi
        echo "FAILED:activitywatch_not_found"
        exit 1
        ;;
    Linux)
        if command -v aw-qt > /dev/null 2>&1; then
            nohup aw-qt > /dev/null 2>&1 &
            disown 2>/dev/null || true
            echo "LAUNCHED"
            exit 0
        fi
        echo "FAILED:aw_qt_not_found"
        exit 1
        ;;
    MINGW*|CYGWIN*|MSYS*)
        # On Windows, the user is expected to launch from Start menu.
        echo "UNSUPPORTED_OS"
        exit 1
        ;;
    *)
        echo "UNSUPPORTED_OS"
        exit 1
        ;;
esac
