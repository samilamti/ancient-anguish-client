#!/usr/bin/env bash
# Push the Play store listing (text + graphics) from scripts/play/listing/.
#
# Inputs:
#   listing/en-US/title.txt                 max 30 chars
#   listing/en-US/short.txt                 max 80 chars
#   listing/en-US/full.txt                  max 4000 chars
#   listing/images/icon.png                 512x512
#   listing/images/featureGraphic.png       1024x500
#   listing/images/phoneScreenshots/*.png   2-8 shots
#
# DRY RUN by default (validates, discards). Pass --go to commit.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=play-api.sh
. "$SCRIPT_DIR/play-api.sh"

LISTING_DIR="$SCRIPT_DIR/listing"
LOCALE="en-US"
GO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --locale) LOCALE="$2"; shift 2 ;;
    --go) GO=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done
TEXT_DIR="$LISTING_DIR/$LOCALE"
for f in title.txt short.txt full.txt; do
  [ -f "$TEXT_DIR/$f" ] || { echo "Missing $TEXT_DIR/$f" >&2; exit 1; }
done

PLAY_TOKEN=$(play_token)
[ -n "$PLAY_TOKEN" ] || { echo "Could not mint Play access token" >&2; exit 1; }

echo "=== Creating edit ==="
RESP=$(play_api POST /edits -H "Content-Type: application/json" -d '{}')
play_check "$RESP" "edits.insert"
EDIT_ID=$(jq -r .id <<<"$RESP")

echo "=== Updating $LOCALE listing text ==="
BODY=$(jq -n --arg lang "$LOCALE" \
  --arg title "$(cat "$TEXT_DIR/title.txt")" \
  --arg short "$(cat "$TEXT_DIR/short.txt")" \
  --rawfile full "$TEXT_DIR/full.txt" \
  '{language: $lang, title: $title, shortDescription: $short, fullDescription: $full}')
RESP=$(play_api PUT "/edits/$EDIT_ID/listings/$LOCALE" \
  -H "Content-Type: application/json" -d "$BODY")
play_check "$RESP" "listings.update"
jq -c '{title, shortDescription}' <<<"$RESP"

upload_image() {
  local type="$1" file="$2" resp
  resp=$(curl -sS --globoff -X POST \
    "$UPLOAD_API/edits/$EDIT_ID/listings/$LOCALE/$type?uploadType=media" \
    -H "Authorization: Bearer $PLAY_TOKEN" \
    -H "Content-Type: image/png" \
    --data-binary @"$file")
  play_check "$resp" "images.upload $type $(basename "$file")"
  echo "  uploaded $type: $(basename "$file")"
}

for TYPE in icon featureGraphic; do
  FILE="$LISTING_DIR/images/$TYPE.png"
  if [ -f "$FILE" ]; then
    echo "=== Replacing $TYPE ==="
    play_api DELETE "/edits/$EDIT_ID/listings/$LOCALE/$TYPE" >/dev/null
    upload_image "$TYPE" "$FILE"
  fi
done

SHOTS_DIR="$LISTING_DIR/images/phoneScreenshots"
if [ -d "$SHOTS_DIR" ]; then
  echo "=== Replacing phoneScreenshots ==="
  play_api DELETE "/edits/$EDIT_ID/listings/$LOCALE/phoneScreenshots" >/dev/null
  for FILE in "$SHOTS_DIR"/*.png; do
    [ -e "$FILE" ] || continue
    upload_image "phoneScreenshots" "$FILE"
  done
fi

if [ "$GO" -eq 1 ]; then
  echo "=== Committing edit ==="
  RESP=$(play_api POST "/edits/$EDIT_ID:commit")
  if jq -e '.error.message? // "" | test("changesNotSentForReview")' >/dev/null 2>&1 <<<"$RESP"; then
    echo "(retrying with changesNotSentForReview=true)"
    RESP=$(play_api POST "/edits/$EDIT_ID:commit?changesNotSentForReview=true")
  fi
  play_check "$RESP" "edits.commit"
  echo "COMMITTED listing for $LOCALE."
else
  echo "=== DRY RUN: validating edit (no commit) ==="
  RESP=$(play_api POST "/edits/$EDIT_ID:validate")
  play_check "$RESP" "edits.validate"
  play_api DELETE "/edits/$EDIT_ID" >/dev/null
  echo "VALIDATED OK. Re-run with --go to commit."
fi
