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
FREERADIUS_CERT_DIR="./docker/freeradius/certs"
FREERADIUS_SERVER_CERT_DIR="$FREERADIUS_CERT_DIR/server"

mkdir -p "$FREERADIUS_SERVER_CERT_DIR"

docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/cert.pem" "$FREERADIUS_SERVER_CERT_DIR/cert.pem"
docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/privkey.pem" "$FREERADIUS_SERVER_CERT_DIR/privkey.pem"
docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/fullchain.pem" "$FREERADIUS_SERVER_CERT_DIR/fullchain.pem"

chmod 644 "$FREERADIUS_SERVER_CERT_DIR/cert.pem" "$FREERADIUS_SERVER_CERT_DIR/fullchain.pem"
chmod 640 "$FREERADIUS_SERVER_CERT_DIR/privkey.pem"
