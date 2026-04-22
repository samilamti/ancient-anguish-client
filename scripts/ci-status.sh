#!/usr/bin/env bash
# Show a colored summary of recent GitHub Actions runs for this repo.
# By default shows the most recent run per workflow. Pass a commit SHA or tag
# to filter to a specific build set (e.g. a release tag).
# Usage:
#   bash scripts/ci-status.sh                 # most recent run per workflow
#   bash scripts/ci-status.sh v6.10.0         # runs for tag v6.10.0 (head commit)
#   bash scripts/ci-status.sh 2e58794         # runs for commit
#   bash scripts/ci-status.sh --watch         # refresh every 20s until all finish
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not installed. brew install gh" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not installed. brew install jq" >&2
  exit 1
fi

WATCH=0
REF=""
for arg in "$@"; do
  case "$arg" in
    --watch|-w) WATCH=1 ;;
    *) REF="$arg" ;;
  esac
done

# Resolve a ref (tag or short SHA) to a full commit SHA.
resolve_sha() {
  local ref="$1"
  git rev-parse "$ref^{commit}" 2>/dev/null || echo "$ref"
}

render() {
  local sha="$1"

  local title="Recent runs"
  if [[ -n "$sha" ]]; then
    local short
    short=$(git rev-parse --short "$sha" 2>/dev/null || echo "$sha")
    title="Runs for $short"
  fi
  echo "=== $title ==="

  local json
  if [[ -n "$sha" ]]; then
    json=$(gh run list --commit "$sha" --limit 30 \
      --json databaseId,workflowName,status,conclusion,headBranch,createdAt,url)
  else
    # Most recent run per workflow across all branches.
    json=$(gh run list --limit 30 \
      --json databaseId,workflowName,status,conclusion,headBranch,createdAt,url \
      | jq 'group_by(.workflowName) | map(sort_by(.createdAt) | last)')
  fi

  # Colored summary lines.
  echo "$json" | jq -r '
    sort_by(.workflowName)[] |
    [.workflowName, .status, .conclusion // "-", .headBranch, .url]
    | @tsv' \
  | while IFS=$'\t' read -r wf status conclusion branch url; do
      case "$status/$conclusion" in
        completed/success)      symbol=$'\033[32m✓\033[0m' ;;
        completed/failure)      symbol=$'\033[31m✗\033[0m' ;;
        completed/cancelled)    symbol=$'\033[33m⊘\033[0m' ;;
        completed/skipped)      symbol=$'\033[90m·\033[0m' ;;
        in_progress/*|queued/*|waiting/*|pending/*) symbol=$'\033[36m…\033[0m' ;;
        *)                      symbol="?" ;;
      esac
      printf "  %s %-22s %-12s %-10s %s\n" "$symbol" "$wf" "$status" "$branch" "$url"
    done

  # Tally counts to drive watch loop.
  echo ""
  echo "$json" | jq -r '
    (map(select(.status == "completed" and .conclusion == "success")) | length) as $ok |
    (map(select(.status == "completed" and .conclusion != "success")) | length) as $bad |
    (map(select(.status != "completed")) | length) as $pending |
    "ok=\($ok) bad=\($bad) pending=\($pending)"' \
    | sed 's/^/  /'
}

loop_until_done() {
  local sha="$1"
  while :; do
    clear
    render "$sha"
    local pending
    pending=$(gh run list ${sha:+--commit "$sha"} --limit 30 \
      --json status \
      | jq 'map(select(.status != "completed")) | length')
    if [[ "$pending" -eq 0 ]]; then
      echo ""
      echo "=== All runs finished ==="
      return
    fi
    echo ""
    echo "(refreshing in 20s; Ctrl-C to stop)"
    sleep 20
  done
}

SHA=""
if [[ -n "$REF" ]]; then
  SHA=$(resolve_sha "$REF")
fi

if [[ $WATCH -eq 1 ]]; then
  loop_until_done "$SHA"
else
  render "$SHA"
fi
