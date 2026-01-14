#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

CERTBOT_CONTAINER_NAME=${EXTERNAL_CERTBOT_CONTAINER:-certbot}
CERTBOT_CERT_NAME=${CERTBOT_CERT_NAME:-${RADIUS_DOMAIN:-radius.example.com}}
CERTBOT_CERT_DIR="/etc/letsencrypt/live/${CERTBOT_CERT_NAME}"
CERT_DIR="./certs"

mkdir -p "$CERT_DIR"

docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/cert.pem" "$CERT_DIR/cert.pem"
docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/privkey.pem" "$CERT_DIR/privkey.pem"
docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/fullchain.pem" "$CERT_DIR/fullchain.pem"

chmod 644 "$CERT_DIR/cert.pem" "$CERT_DIR/fullchain.pem"
chmod 640 "$CERT_DIR/privkey.pem"

echo "Certificates copied to $CERT_DIR"
