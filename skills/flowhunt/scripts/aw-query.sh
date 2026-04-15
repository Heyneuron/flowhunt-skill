#!/usr/bin/env bash
# Query ActivityWatch for the last N days, AFK-filtered, aggregated by
# (app, title), sorted by duration descending.
#
# Usage: aw-query.sh <days>              -> JSON of top 100 (app, title, seconds)
#        aw-query.sh <days> --raw        -> raw ActivityWatch response
#
# The AQL query below is ported from the original flowhunt
# app/lib/activitywatch.ts (fetchDailySummary) which uses:
#   - window watcher bucket (per-app, per-window-title events)
#   - AFK watcher bucket filtered to "not-afk" status
#   - period intersection (drop time spent AFK)
#   - merge by (app, title) to collapse noise
#
# Requires: curl, jq

set -euo pipefail

AW_BASE="http://localhost:5600/api/0"
DAYS="${1:-30}"
RAW_MODE="${2:-}"

if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    echo "Error: first argument must be a positive integer (number of days)" >&2
    exit 1
fi

# Build time period: from N days ago 00:00 UTC to tomorrow 00:00 UTC
start_date=$(date -u -v-"${DAYS}"d +"%Y-%m-%d" 2>/dev/null || date -u -d "${DAYS} days ago" +"%Y-%m-%d")
end_date=$(date -u -v+1d +"%Y-%m-%d" 2>/dev/null || date -u -d "+1 day" +"%Y-%m-%d")
period="${start_date}T00:00:00+00:00/${end_date}T00:00:00+00:00"

# AQL query - one statement per semicolon, joined into a single string
# as required by ActivityWatch's /query/ endpoint.
query='events = flood(query_bucket(find_bucket("aw-watcher-window_"))); not_afk = flood(query_bucket(find_bucket("aw-watcher-afk_"))); not_afk = filter_keyvals(not_afk, "status", ["not-afk"]); events = filter_period_intersect(events, not_afk); events = merge_events_by_keys(events, ["app", "title"]); RETURN = sort_by_duration(events);'

payload=$(jq -n \
    --arg period "$period" \
    --arg query "$query" \
    '{timeperiods: [$period], query: [$query]}')

response=$(curl -fsS \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$AW_BASE/query/") || {
    echo "Error: ActivityWatch query failed. Is the server running on $AW_BASE ?" >&2
    exit 1
}

if [ "$RAW_MODE" = "--raw" ]; then
    echo "$response"
    exit 0
fi

# Shape: [ [event, event, ...] ] for a single timeperiod.
# Extract top 100 by duration, emit {app, title, seconds} records.
echo "$response" | jq '
    .[0]
    | map(select(.duration >= 30))
    | sort_by(-.duration)
    | .[0:100]
    | map({
        app: .data.app,
        title: (.data.title // ""),
        seconds: (.duration | floor)
    })
'
