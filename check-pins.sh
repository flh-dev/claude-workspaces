#!/usr/bin/env bash
# Reminds to review the third-party plugins pinned by sha in the workspaces marketplace.
#
#   check-pins.sh             SessionStart hook mode: silent unless a review is due (>30 days)
#                             and at least one pin is behind upstream
#   check-pins.sh --report    print every pin with its status
#   check-pins.sh --reviewed  record today as the last review (after bumping or accepting pins)
#
# Compares against the upstream branch head, so a git-subdir pin can show "behind"
# because of commits outside its subdirectory.
set -uo pipefail

DIR="$HOME/.claude/workspaces"
MARKETPLACE="$DIR/.claude-plugin/marketplace.json"
REVIEWED_FILE="$DIR/.pins-reviewed"   # date of the last review, YYYY-MM-DD
STATUS_FILE="$DIR/.pins-status"       # cached result of the last upstream check
REVIEW_EVERY_DAYS=30

days_since() { echo $(( ( $(date +%s) - $(date -d "$1" +%s) ) / 86400 )); }

EXTRA_PINS="$DIR/pins-extra.tsv"     # pins outside the marketplace, e.g. locally built Docker images

# One line per pin: name<TAB>git url<TAB>ref<TAB>pinned sha
pins() {
  jq -r '.plugins[] | select(.source | type == "object" and has("sha")) |
    [ .name,
      (if .source.source == "github" then "https://github.com/\(.source.repo).git" else .source.url end),
      (.source.ref // "HEAD"),
      .source.sha ] | @tsv' "$MARKETPLACE"
  [ -f "$EXTRA_PINS" ] && grep -v '^#' "$EXTRA_PINS"
}

# Writes "name<TAB>current|behind|unreachable" lines to the status file, in pin order.
# Upstreams are queried in parallel so the hook stays well under its 60 s timeout;
# the temp file is unique and moved into place, so concurrent session starts can't mix results.
check_upstream() {
  local tmp index=0
  tmp=$(mktemp "$STATUS_FILE.XXXXXX")
  while IFS=$'\t' read -r name url ref sha; do
    index=$((index + 1))
    (
      head=$(timeout 10 git ls-remote "$url" "$ref" 2>/dev/null | head -1 | cut -f1)
      if [ -z "$head" ]; then state=unreachable
      elif [ "$head" = "$sha" ]; then state=current
      else state=behind; fi
      printf '%d\t%s\t%s\n' "$index" "$name" "$state" >> "$tmp"
    ) &
  done < <(pins)
  wait
  sort -n "$tmp" | cut -f2- > "$tmp.sorted" && mv "$tmp.sorted" "$STATUS_FILE"
  rm -f "$tmp"
}

case "${1:-}" in
  --reviewed)
    date +%F > "$REVIEWED_FILE"; rm -f "$STATUS_FILE"
    echo "Pin review recorded for $(date +%F)."; exit 0 ;;
  --report)
    check_upstream
    echo "Last review: $(cat "$REVIEWED_FILE" 2>/dev/null || echo never)"
    column -t -s $'\t' "$STATUS_FILE"; exit 0 ;;
esac

# Hook mode: must stay fast and never fail the session start
last=$(cat "$REVIEWED_FILE" 2>/dev/null || echo 1970-01-01)
last_label=$([ "$last" = 1970-01-01 ] && echo never || echo "$last")
[ "$(days_since "$last")" -lt "$REVIEW_EVERY_DAYS" ] && exit 0

# Reuse today's upstream check instead of hitting the network on every session start
if [ ! -f "$STATUS_FILE" ] || [ "$(date -r "$STATUS_FILE" +%F)" != "$(date +%F)" ]; then
  check_upstream
fi

behind=$(awk -F'\t' '$2 == "behind" { print $1 }' "$STATUS_FILE" | paste -sd, - | sed 's/,/, /g')
if [ -z "$behind" ]; then
  # Only a check that reached every upstream proves nothing changed. Otherwise drop the
  # cached result so the next session start retries, and keep the review due.
  # An empty status means no pin was read at all (e.g. a broken marketplace.json).
  if [ ! -s "$STATUS_FILE" ] || grep -q $'\tunreachable$' "$STATUS_FILE"; then
    rm -f "$STATUS_FILE"
  else
    date +%F > "$REVIEWED_FILE"   # nothing changed upstream, so the review is trivially done
  fi
  exit 0
fi

message="Workspace pins due for review (last review $last_label). Updates upstream: $behind. Ask Claude: \"review the workspace pins\"."
jq -n --arg m "$message" '{
  systemMessage: $m,
  hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: ("[workspace pins] " + $m + " Review = diff each behind repo between pinned sha and upstream, check for new scripts/hooks/MCP servers or prompt injection, bump sha in ~/.claude/workspaces/.claude-plugin/marketplace.json, validate, then run ~/.claude/workspaces/check-pins.sh --reviewed.") }
}'
