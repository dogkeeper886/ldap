#!/bin/sh
# Certbot deploy hook: runs only when a certificate was actually renewed.
# Propagates the renewed cert to every service that uses it so none keeps
# serving an expired certificate. See docs/05-cert-renewal-automation.md.
#
# Certbot sets RENEWED_LINEAGE (/etc/letsencrypt/live/<name>) when invoking a
# --deploy-hook. REPO is the repository root mounted into the certbot container.
set -eu

REPO=${REPO:-/workspace}
LINEAGE=${RENEWED_LINEAGE:-/etc/letsencrypt/live/${CERTBOT_CERT_NAME:-}}

echo "[deploy-hook] Renewed lineage: $LINEAGE"

# Copy cert.pem / privkey.pem / fullchain.pem into a service's cert dir.
# Uses an explicit && chain so it returns non-zero on any failure: callers run
# it in best-effort contexts where set -e is suppressed, so we cannot rely on it.
copy_certs() {
    dest="$1"
    cp "$LINEAGE/cert.pem"      "$dest/cert.pem"      &&
    cp "$LINEAGE/privkey.pem"   "$dest/privkey.pem"   &&
    cp "$LINEAGE/fullchain.pem" "$dest/fullchain.pem" &&
    chmod 644 "$dest/cert.pem" "$dest/fullchain.pem"  &&
    chmod 640 "$dest/privkey.pem"
}

# Refresh one service group best-effort: copy certs into each dir, then run
# compose. A failure is logged and does not block the other groups.
# $1 = label, $2 = compose dir, $3 = space-separated cert dirs, rest = compose args.
refresh() {
    label="$1"; dir="$2"; dests="$3"; shift 3
    for d in $dests; do
        if ! copy_certs "$d"; then
            echo "[deploy-hook] WARNING: cert copy failed for $label ($d); skipping" >&2
            return 0
        fi
    done
    if ( cd "$REPO/$dir" && docker compose "$@" ); then
        echo "[deploy-hook] Refreshed $label"
    else
        echo "[deploy-hook] WARNING: deploy failed for $label" >&2
    fi
}

# Baked-in certs (Dockerfile COPY) -> rebuild + recreate.
# freeradius and mcp-radius-sql share freeradius/docker-compose.yml.
refresh "freeradius+mcp" freeradius \
    "$REPO/freeradius/docker/freeradius/certs/server $REPO/mcp-radius-sql/certs" \
    up -d --build freeradius mcp-radius-sql
refresh "ldap" ldap "$REPO/ldap/docker/certs" up -d --build

# Runtime-mounted certs (read-only bind mount) -> force-recreate to reload.
refresh "keycloak" keycloak "$REPO/keycloak/docker/certs" up -d --force-recreate
refresh "mail"     mail     "$REPO/mail/docker/certs"     up -d --force-recreate

echo "[deploy-hook] Certificate propagation complete"
