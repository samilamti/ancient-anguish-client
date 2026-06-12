#!/usr/bin/env bash
# Assign an ALREADY-UPLOADED versionCode to a Play track (promote/stage)
# without re-uploading the bundle.
#
#   bash scripts/play/set-track.sh --track alpha --vc 62000 --status draft --go
#   bash scripts/play/set-track.sh --track internal --vc 62000 --notes "..." --go
#
# Status rules while the app is a DRAFT app:
#   internal            -> --status completed (live to internal testers at once)
#   alpha/beta/prod     -> --status draft ("Only releases with status draft may
#                          be created on draft app"), then Preview-and-confirm
#                          + Send for review in the Console.
# DRY RUN by default: validates the edit and discards. --go commits.
# Proven end-to-end 2026-06-11 (alpha draft staging of versionCode 62000).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=play-api.sh
. "$SCRIPT_DIR/play-api.sh"

TRACK=""
VC=""
STATUS="completed"
NOTES=""
GO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --track) TRACK="$2"; shift 2 ;;
    --vc) VC="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --notes) NOTES="$2"; shift 2 ;;
    --go) GO=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done
[ -n "$TRACK" ] && [ -n "$VC" ] || { echo "Usage: set-track.sh --track <t> --vc <code> [--status draft|completed] [--notes ...] [--go]" >&2; exit 1; }

PLAY_TOKEN=$(play_token)
[ -n "$PLAY_TOKEN" ] || { echo "Could not mint Play access token" >&2; exit 1; }

RESP=$(play_api POST /edits -H "Content-Type: application/json" -d '{}')
play_check "$RESP" "edits.insert"
EDIT_ID=$(jq -r .id <<<"$RESP")

BODY=$(jq -n --arg track "$TRACK" --arg vc "$VC" --arg status "$STATUS" --arg notes "$NOTES" \
  '{track: $track,
    releases: [({versionCodes: [$vc], status: $status}
      + (if $notes != "" then {releaseNotes: [{language: "en-US", text: $notes}]} else {} end))]}')
RESP=$(play_api PUT "/edits/$EDIT_ID/tracks/$TRACK" -H "Content-Type: application/json" -d "$BODY")
play_check "$RESP" "tracks.update $TRACK"
jq -c '{track, releases: [.releases[] | {status, versionCodes}]}' <<<"$RESP"

if [ "$GO" -eq 1 ]; then
  RESP=$(play_api POST "/edits/$EDIT_ID:commit")
  if jq -e '.error.message? // "" | test("changesNotSentForReview")' >/dev/null 2>&1 <<<"$RESP"; then
    echo "(retrying with changesNotSentForReview=true)"
    RESP=$(play_api POST "/edits/$EDIT_ID:commit?changesNotSentForReview=true")
  fi
  play_check "$RESP" "edits.commit"
  echo "COMMITTED: $VC on '$TRACK' (status $STATUS)"
else
  RESP=$(play_api POST "/edits/$EDIT_ID:validate")
  play_check "$RESP" "edits.validate"
  play_api DELETE "/edits/$EDIT_ID" >/dev/null
  echo "VALIDATED OK (dry run). Re-run with --go to commit."
fi
