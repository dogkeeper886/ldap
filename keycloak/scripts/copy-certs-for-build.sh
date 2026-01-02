#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

CERTBOT_CONTAINER_NAME=${EXTERNAL_CERTBOT_CONTAINER:-certbot}
CERTBOT_CERT_NAME=${CERTBOT_CERT_NAME:-${KEYCLOAK_DOMAIN:-keycloak.example.com}}
CERTBOT_CERT_DIR="/etc/letsencrypt/live/${CERTBOT_CERT_NAME}"
KEYCLOAK_CERT_DIR="./docker/certs"

mkdir -p "$KEYCLOAK_CERT_DIR"

docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/cert.pem" "$KEYCLOAK_CERT_DIR/cert.pem"
docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/privkey.pem" "$KEYCLOAK_CERT_DIR/privkey.pem"
docker cp --follow-link "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/fullchain.pem" "$KEYCLOAK_CERT_DIR/fullchain.pem"

chmod 644 "$KEYCLOAK_CERT_DIR/cert.pem" "$KEYCLOAK_CERT_DIR/fullchain.pem"
chmod 644 "$KEYCLOAK_CERT_DIR/privkey.pem"

echo "Certificates copied to $KEYCLOAK_CERT_DIR"
