#!/usr/bin/env bash
# publish.sh — rsync the website/ directory to the Hetzner box.
#
# Usage:
#   bash scripts/website/publish.sh          # dry-run (default)
#   bash scripts/website/publish.sh --go     # actually upload
#
# Honors:
#   SSH_USER  — remote user (default: root)
#   SSH_HOST  — remote host (default: only-clerics.duckdns.org)
#   SSH_KEY   — optional absolute path to an SSH private key (default: agent / ~/.ssh/config)
#   REMOTE_DIR — remote target directory (default: /srv/aa)
#
# Trailing-slash semantics: SOURCE has a trailing slash so rsync merges
# the CONTENTS of website/ into /srv/aa/ rather than nesting a website/
# subdirectory on the server.

set -u
cd "$(dirname "$0")/../.."

SOURCE_DIR="website/"

GO=0
for arg in "$@"; do
    [ "$arg" = "--go" ] && GO=1
done

SSH_USER="${SSH_USER:-root}"
SSH_HOST="${SSH_HOST:-only-clerics.duckdns.org}"
SSH_KEY="${SSH_KEY:-}"
REMOTE_DIR="${REMOTE_DIR:-/srv/aa}"

# --- Sanity checks --------------------------------------------------------

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: source not found: $SOURCE_DIR (run from repo root)" >&2
    exit 1
fi

# --- Banner ---------------------------------------------------------------

mode_label="DRY RUN (preview only — pass --go to actually upload)"
[ "$GO" -eq 1 ] && mode_label="REAL UPLOAD"

ssh_key_label="(ssh-agent / ssh config)"
[ -n "$SSH_KEY" ] && ssh_key_label="$SSH_KEY"

echo "================================================================"
echo "  publish.sh — Ancient Anguish Client website"
echo "  Source:      $(pwd)/$SOURCE_DIR"
echo "  Destination: $SSH_USER@$SSH_HOST:$REMOTE_DIR/"
echo "  Key:         $ssh_key_label"
echo "  Mode:        $mode_label"
echo "================================================================"
echo

# --- Run ------------------------------------------------------------------

# bash 3.2 (default on macOS) trips `set -u` on empty array expansion, so
# build optional flags as strings rather than arrays.
DRY=""
[ "$GO" -eq 0 ] && DRY="--dry-run"

SSH_KEY_FLAG=""
if [ -n "$SSH_KEY" ]; then
    if [ ! -f "$SSH_KEY" ]; then
        echo "ERROR: SSH key not found: $SSH_KEY" >&2
        exit 1
    fi
    chmod 600 "$SSH_KEY"
    SSH_KEY_FLAG="-i \"$SSH_KEY\""
fi

rsync -avz --human-readable --progress --delete $DRY \
    -e "ssh $SSH_KEY_FLAG -o StrictHostKeyChecking=accept-new" \
    "$SOURCE_DIR" \
    "$SSH_USER@$SSH_HOST:$REMOTE_DIR/"

rc=$?
echo
if [ "$rc" -eq 0 ]; then
    echo "rsync exit 0 (success)."
    if [ "$GO" -eq 0 ]; then
        echo "Re-run with --go to perform the real upload."
    else
        echo
        echo "Verify with:"
        echo "  curl -I https://ancient-anguish.duckdns.org/"
        echo "  curl -I https://ancient-anguish.duckdns.org/support.html"
        echo "  curl -I https://ancient-anguish.duckdns.org/privacy.html"
    fi
else
    echo "rsync exit $rc (error). See output above."
fi
exit "$rc"
