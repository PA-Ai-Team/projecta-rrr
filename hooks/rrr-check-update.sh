#!/bin/bash
# Check for RRR updates in background, write result to cache
# Called by SessionStart hook - runs once per session

CACHE_FILE="$HOME/.claude/cache/rrr-update-check.json"
mkdir -p "$HOME/.claude/cache"

# Run check in background (non-blocking)
(
  installed=$(cat "$HOME/.claude/rrr/VERSION" 2>/dev/null || echo "0.0.0")
  latest=$(npm view projecta-rrr version 2>/dev/null)

  if [[ -n "$latest" && "$installed" != "$latest" ]]; then
    echo "{\"update_available\":true,\"installed\":\"$installed\",\"latest\":\"$latest\",\"checked\":$(date +%s)}" > "$CACHE_FILE"
  else
    echo "{\"update_available\":false,\"installed\":\"$installed\",\"latest\":\"${latest:-unknown}\",\"checked\":$(date +%s)}" > "$CACHE_FILE"
  fi
) &

exit 0
