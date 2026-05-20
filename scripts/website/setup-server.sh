#!/usr/bin/env bash
# setup-server.sh — one-time setup of the ancient-anguish.duckdns.org vhost on the Hetzner box.
#
# Idempotent: safe to re-run. Detects nginx, drops in a server block, runs
# certbot for TLS, reloads nginx.
#
# Prereq (manual): ancient-anguish.duckdns.org must already exist in your DuckDNS account
# pointing at the same Hetzner IP as only-clerics.duckdns.org. DuckDNS
# subdomain creation is web-UI-only — log in at https://www.duckdns.org/,
# add `aa` as a new domain, point it at 91.99.169.123, save.
#
# Usage:
#   bash scripts/website/setup-server.sh
#
# Honors:
#   SSH_USER         — remote user (default: root)
#   SSH_HOST         — remote host for control (default: only-clerics.duckdns.org)
#   SSH_KEY          — optional absolute path to an SSH key
#   DOMAIN           — vhost server_name (default: ancient-anguish.duckdns.org)
#   REMOTE_DIR       — content directory on the box (default: /srv/aa)
#   CERTBOT_EMAIL    — Let's Encrypt registration email (default: sami.lamti@gmail.com)
#   EXPECTED_IP      — IP DNS should resolve to (default: 91.99.169.123)

set -eu

SSH_USER="${SSH_USER:-root}"
SSH_HOST="${SSH_HOST:-only-clerics.duckdns.org}"
SSH_KEY="${SSH_KEY:-}"
DOMAIN="${DOMAIN:-ancient-anguish.duckdns.org}"
REMOTE_DIR="${REMOTE_DIR:-/srv/aa}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-sami.lamti@gmail.com}"
EXPECTED_IP="${EXPECTED_IP:-91.99.169.123}"

SSH_OPTS="-o StrictHostKeyChecking=accept-new"
if [ -n "$SSH_KEY" ]; then
    if [ ! -f "$SSH_KEY" ]; then
        echo "ERROR: SSH key not found: $SSH_KEY" >&2
        exit 1
    fi
    chmod 600 "$SSH_KEY"
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

echo "================================================================"
echo "  setup-server.sh — $DOMAIN on $SSH_USER@$SSH_HOST"
echo "================================================================"
echo

# --- Step 1: verify DuckDNS resolves to the expected IP -------------------

echo "[1/5] Verifying $DOMAIN resolves to $EXPECTED_IP …"
RESOLVED=$(dig +short "$DOMAIN" | tail -n 1)
if [ -z "$RESOLVED" ]; then
    cat >&2 <<EOF
ERROR: $DOMAIN does not resolve to anything.

DuckDNS subdomain creation is web-UI-only. Open https://www.duckdns.org/
in a browser, log in, type 'ancient-anguish' in the "add domain" field, point it at
$EXPECTED_IP, and save. Then re-run this script.
EOF
    exit 1
fi
if [ "$RESOLVED" != "$EXPECTED_IP" ]; then
    echo "WARNING: $DOMAIN resolves to $RESOLVED (expected $EXPECTED_IP)." >&2
    echo "Continuing anyway. Make sure this IP is correct for the target box." >&2
fi
echo "  OK: $DOMAIN -> $RESOLVED"
echo

# --- Step 2: detect nginx on the remote -----------------------------------

echo "[2/5] Detecting web server on $SSH_HOST …"
WEB_STATUS=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" '
    if command -v nginx >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
        echo "nginx"
    elif systemctl is-active --quiet caddy 2>/dev/null; then
        echo "caddy"
    else
        echo "none"
    fi
')

case "$WEB_STATUS" in
    nginx)
        echo "  OK: nginx is active"
        ;;
    caddy)
        cat >&2 <<EOF
ERROR: this box runs Caddy, not nginx. This script only supports nginx.
Add a Caddyfile entry manually:

  $DOMAIN {
      root * $REMOTE_DIR
      file_server
      try_files {path} {path}.html {path}/ =404
  }

Then reload Caddy. Caddy handles TLS automatically; no certbot step needed.
EOF
        exit 1
        ;;
    *)
        cat >&2 <<EOF
ERROR: no recognized web server (nginx/caddy) is active on $SSH_HOST.
Install nginx + certbot first:

  apt-get update && apt-get install -y nginx certbot python3-certbot-nginx

Then re-run this script.
EOF
        exit 1
        ;;
esac
echo

# --- Steps 3–5: provision the vhost via a single remote shell ------------

NGINX_CONF_PATH="/etc/nginx/sites-available/${DOMAIN}.conf"
NGINX_ENABLED_PATH="/etc/nginx/sites-enabled/${DOMAIN}.conf"

echo "[3/5] Provisioning $REMOTE_DIR and nginx vhost …"

ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "DOMAIN='$DOMAIN' REMOTE_DIR='$REMOTE_DIR' NGINX_CONF_PATH='$NGINX_CONF_PATH' NGINX_ENABLED_PATH='$NGINX_ENABLED_PATH' CERTBOT_EMAIL='$CERTBOT_EMAIL' bash -s" <<'REMOTE'
set -eu

# Create content directory if missing
mkdir -p "$REMOTE_DIR"
# Drop a placeholder so nginx can start before publish.sh runs
if [ ! -f "$REMOTE_DIR/index.html" ]; then
    echo '<!doctype html><meta charset=utf-8><title>ancient-anguish.duckdns.org</title><p>Coming soon.</p>' > "$REMOTE_DIR/index.html"
fi

# Write nginx server block (idempotent — overwrite)
cat > "$NGINX_CONF_PATH" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${REMOTE_DIR};
    index index.html;

    # Resolve /support -> /support.html, /privacy -> /privacy.html, etc.
    location / {
        try_files \$uri \$uri.html \$uri/ =404;
    }

    # Sensible cache headers for static assets
    location ~* \.(css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 7d;
        add_header Cache-Control "public, max-age=604800";
    }
}
NGINX

# Enable the site
ln -sf "$NGINX_CONF_PATH" "$NGINX_ENABLED_PATH"

echo "  -> wrote $NGINX_CONF_PATH"

# Test config; reload only if valid
if ! nginx -t 2>&1; then
    echo "ERROR: nginx -t failed; not reloading" >&2
    exit 1
fi
systemctl reload nginx
echo "  -> nginx reloaded (HTTP only; TLS next)"
REMOTE

echo

# --- Step 4: certbot for TLS ---------------------------------------------

echo "[4/5] Obtaining Let's Encrypt certificate for $DOMAIN …"
ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "DOMAIN='$DOMAIN' CERTBOT_EMAIL='$CERTBOT_EMAIL' bash -s" <<'REMOTE'
set -eu

if ! command -v certbot >/dev/null 2>&1; then
    echo "ERROR: certbot not installed. Run: apt-get install -y certbot python3-certbot-nginx" >&2
    exit 1
fi

# If a cert already exists, --keep-until-expiring is a no-op; otherwise issue.
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email "$CERTBOT_EMAIL" \
    --domains "$DOMAIN" \
    --redirect \
    --keep-until-expiring
REMOTE

echo

# --- Step 5: final smoke test --------------------------------------------

echo "[5/5] Verifying HTTPS reachability …"
sleep 2
if curl -fsSI "https://${DOMAIN}/" >/dev/null; then
    echo "  OK: https://${DOMAIN}/ responds 2xx"
else
    echo "WARNING: HTTPS check failed (rc=$?). Try again in a few seconds." >&2
fi

echo
echo "Setup complete. Next:"
echo "  bash scripts/website/publish.sh --go"
