#!/usr/bin/env bash
# Upload the release AAB to a Google Play track.
#
# DRY RUN by default: uploads into a temporary edit, validates it server-side,
# then deletes the edit. Pass --go to commit for real.
#
# Usage:
#   bash scripts/play/publish-aab.sh                  # validate only
#   bash scripts/play/publish-aab.sh --go             # internal track, live
#   bash scripts/play/publish-aab.sh --track alpha --notes "Closed test" --go
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=play-api.sh
. "$SCRIPT_DIR/play-api.sh"

AAB="$SCRIPT_DIR/../../build/app/outputs/bundle/release/app-release.aab"
TRACK="internal"
NOTES=""
GO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --aab) AAB="$2"; shift 2 ;;
    --track) TRACK="$2"; shift 2 ;;
    --notes) NOTES="$2"; shift 2 ;;
    --go) GO=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done
[ -f "$AAB" ] || { echo "AAB not found: $AAB (run flutter build appbundle)" >&2; exit 1; }

PLAY_TOKEN=$(play_token)
[ -n "$PLAY_TOKEN" ] || { echo "Could not mint Play access token" >&2; exit 1; }

echo "=== Creating edit ==="
RESP=$(play_api POST /edits -H "Content-Type: application/json" -d '{}')
play_check "$RESP" "edits.insert"
EDIT_ID=$(jq -r .id <<<"$RESP")
echo "Edit: $EDIT_ID"

echo "=== Uploading $(basename "$AAB") ($(du -h "$AAB" | cut -f1 | tr -d ' ')) ==="
RESP=$(curl -sS --globoff -X POST \
  "$UPLOAD_API/edits/$EDIT_ID/bundles?uploadType=media" \
  -H "Authorization: Bearer $PLAY_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$AAB")
play_check "$RESP" "bundles.upload"
VC=$(jq -r .versionCode <<<"$RESP")
echo "Uploaded versionCode=$VC sha256=$(jq -r .sha256 <<<"$RESP" | cut -c1-16)..."

echo "=== Assigning versionCode $VC to track '$TRACK' ==="
BODY=$(jq -n --arg track "$TRACK" --arg vc "$VC" --arg notes "$NOTES" \
  '{track: $track,
    releases: [({versionCodes: [$vc], status: "completed"}
      + (if $notes != "" then {releaseNotes: [{language: "en-US", text: $notes}]} else {} end))]}')
RESP=$(play_api PUT "/edits/$EDIT_ID/tracks/$TRACK" \
  -H "Content-Type: application/json" -d "$BODY")
play_check "$RESP" "tracks.update"
jq -c '{track, releases: [.releases[] | {status, versionCodes}]}' <<<"$RESP"

if [ "$GO" -eq 1 ]; then
  echo "=== Committing edit ==="
  RESP=$(play_api POST "/edits/$EDIT_ID:commit")
  # A draft-state app (pre-review) requires the changesNotSentForReview flag.
  if jq -e '.error.message? // "" | test("changesNotSentForReview")' >/dev/null 2>&1 <<<"$RESP"; then
    echo "(retrying with changesNotSentForReview=true)"
    RESP=$(play_api POST "/edits/$EDIT_ID:commit?changesNotSentForReview=true")
  fi
  play_check "$RESP" "edits.commit"
  echo "COMMITTED: versionCode $VC is on the '$TRACK' track."
else
  echo "=== DRY RUN: validating edit (no commit) ==="
  RESP=$(play_api POST "/edits/$EDIT_ID:validate")
  play_check "$RESP" "edits.validate"
  play_api DELETE "/edits/$EDIT_ID" >/dev/null
  echo "VALIDATED OK. Re-run with --go to commit to '$TRACK'."
fi
