#!/usr/bin/env bash
# Check whether ActivityWatch is installed and running on localhost:5600.
# Prints one of: OK | NOT_RUNNING | NOT_INSTALLED
# Exit code: 0 = OK, 1 = NOT_RUNNING, 2 = NOT_INSTALLED
#
# OK means the server responded to /api/0/info AND has at least one
# window watcher bucket (otherwise we got only the server, no actual data).

AW_BASE="http://localhost:5600/api/0"

# 1. Is the server responding at all?
if ! curl -fsS --max-time 2 "$AW_BASE/info" > /dev/null 2>&1; then
    # Server not responding. Is the binary even installed?
    if command -v aw-qt > /dev/null 2>&1; then
        echo "NOT_RUNNING"
        exit 1
    fi
    # macOS cask path
    if [ -d "/Applications/ActivityWatch.app" ]; then
        echo "NOT_RUNNING"
        exit 1
    fi
    echo "NOT_INSTALLED"
    exit 2
fi

# 2. Server is up. Confirm at least one window watcher bucket exists.
buckets=$(curl -fsS --max-time 2 "$AW_BASE/buckets/" 2>/dev/null)
if [ -z "$buckets" ]; then
    echo "NOT_RUNNING"
    exit 1
fi

if ! echo "$buckets" | grep -q "aw-watcher-window"; then
    # Server is running but no window watcher registered yet — treat as
    # not-running for the purpose of setup because we cannot query anything.
    echo "NOT_RUNNING"
    exit 1
fi

echo "OK"
exit 0
