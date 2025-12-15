#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

CERTBOT_CONTAINER="certbot"
CERT_SOURCE="/etc/letsencrypt/live/${PRIMARY_CERT_DOMAIN}"
CERT_DEST="./docker/certs"

mkdir -p "$CERT_DEST"

docker exec "$CERTBOT_CONTAINER" cat "$CERT_SOURCE/fullchain.pem" > "$CERT_DEST/fullchain.pem"
docker exec "$CERTBOT_CONTAINER" cat "$CERT_SOURCE/privkey.pem" > "$CERT_DEST/privkey.pem"

chmod 644 "$CERT_DEST/fullchain.pem"
chmod 640 "$CERT_DEST/privkey.pem"

echo "Certificates copied to $CERT_DEST"
