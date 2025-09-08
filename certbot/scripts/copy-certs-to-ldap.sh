#!/bin/bash
# Copy certificates from standalone certbot to LDAP project

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Configuration
CERTBOT_CONTAINER_NAME=${CERTBOT_CONTAINER_NAME:-standalone-certbot}
PRIMARY_DOMAIN=${LDAP_DOMAIN:-ldap.example.com}
LDAP_PROJECT_PATH=${LDAP_PROJECT_PATH:-../ldap}
CERT_SOURCE_DIR="/etc/letsencrypt/live/${PRIMARY_DOMAIN}"
CERT_DEST_DIR="$LDAP_PROJECT_PATH/docker/openldap/certs"

echo "Copying certificates to LDAP project..."
echo "Source: $CERTBOT_CONTAINER_NAME:$CERT_SOURCE_DIR"
echo "Destination: $CERT_DEST_DIR"

# Create destination directory
mkdir -p "$CERT_DEST_DIR"

# Copy certificates
docker cp "$CERTBOT_CONTAINER_NAME:$CERT_SOURCE_DIR/cert.pem" "$CERT_DEST_DIR/cert.pem"
docker cp "$CERTBOT_CONTAINER_NAME:$CERT_SOURCE_DIR/privkey.pem" "$CERT_DEST_DIR/privkey.pem"
docker cp "$CERTBOT_CONTAINER_NAME:$CERT_SOURCE_DIR/fullchain.pem" "$CERT_DEST_DIR/fullchain.pem"

# Set permissions
chmod 644 "$CERT_DEST_DIR/cert.pem" "$CERT_DEST_DIR/fullchain.pem"
chmod 640 "$CERT_DEST_DIR/privkey.pem"

echo "✓ Certificates copied to LDAP project successfully"