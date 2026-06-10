#!/usr/bin/env bash
# Shared helpers for the Google Play Developer API (v3).
#
# Auth: a service-account JSON key stored base64-encoded in the macOS
# Keychain (never on disk). Base64 because `security` hex-mangles multi-line
# values on retrieval. To (re)install the credential:
#   security add-generic-password -U -a play-publisher \
#     -s aa-client-play-sa-json -w "$(base64 -i service-account.json | tr -d '\n')"
# The service account must be invited under Play Console > Users and
# permissions with release-management access to the app.
#
# Source this file; it exposes:
#   play_token        mint a 1h OAuth2 access token (RS256 JWT exchange)
#   play_api          curl wrapper for $API (JSON endpoints)
#   PKG / API / UPLOAD_API constants
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

PKG="org.ancientanguish.ancient_anguish_client"
KEYCHAIN_SERVICE="aa-client-play-sa-json"
KEYCHAIN_ACCOUNT="play-publisher"
API="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PKG"
UPLOAD_API="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PKG"

_b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

play_token() {
  local sa_json client_email private_key now exp hdr clm sig jwt
  sa_json=$(security find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w | base64 -d) || {
    echo "Service-account JSON not found in Keychain ($KEYCHAIN_SERVICE)" >&2
    return 1
  }
  client_email=$(jq -r .client_email <<<"$sa_json")
  private_key=$(jq -r .private_key <<<"$sa_json")
  now=$(date +%s)
  exp=$((now + 3600))
  hdr=$(printf '{"alg":"RS256","typ":"JWT"}' | _b64url)
  clm=$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/androidpublisher","aud":"https://oauth2.googleapis.com/token","iat":%d,"exp":%d}' \
    "$client_email" "$now" "$exp" | _b64url)
  sig=$(printf '%s.%s' "$hdr" "$clm" |
    openssl dgst -sha256 -sign <(printf '%s' "$private_key") -binary | _b64url)
  jwt="$hdr.$clm.$sig"
  curl -sS --globoff -X POST https://oauth2.googleapis.com/token \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    --data-urlencode "assertion=$jwt" | jq -r '.access_token // empty'
}

# play_api METHOD /path [extra curl args...] -- path is relative to $API.
play_api() {
  local method="$1" path="$2"
  shift 2
  curl -sS --globoff -X "$method" "$API$path" \
    -H "Authorization: Bearer $PLAY_TOKEN" "$@"
}

# Fail loudly when a JSON response carries an API error.
play_check() {
  local resp="$1" context="$2"
  if jq -e '.error' >/dev/null 2>&1 <<<"$resp"; then
    echo "Play API error during $context:" >&2
    jq '.error' <<<"$resp" >&2
    return 1
  fi
}
