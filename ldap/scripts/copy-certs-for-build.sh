#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

EXTERNAL_CERTBOT_CONTAINER="standalone-certbot"
PRIMARY_DOMAIN=${LDAP_DOMAIN:-ldap.example.com}
CERT_SOURCE_DIR="/etc/letsencrypt/live/${PRIMARY_DOMAIN}"
CERT_DEST_DIR="./docker/certs"

mkdir -p "$CERT_DEST_DIR"

docker cp "$EXTERNAL_CERTBOT_CONTAINER:$CERT_SOURCE_DIR/cert.pem" "$CERT_DEST_DIR/cert.pem"
docker cp "$EXTERNAL_CERTBOT_CONTAINER:$CERT_SOURCE_DIR/privkey.pem" "$CERT_DEST_DIR/privkey.pem"
docker cp "$EXTERNAL_CERTBOT_CONTAINER:$CERT_SOURCE_DIR/fullchain.pem" "$CERT_DEST_DIR/fullchain.pem"

chmod 644 "$CERT_DEST_DIR/cert.pem" "$CERT_DEST_DIR/fullchain.pem"
chmod 640 "$CERT_DEST_DIR/privkey.pem"
