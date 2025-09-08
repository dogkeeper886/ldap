#!/bin/bash
# Test certificate validity and configuration

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
CERT_SOURCE_DIR="/etc/letsencrypt/live/${PRIMARY_DOMAIN}"

echo "=== Certificate Validation Test ==="
echo "Container: $CERTBOT_CONTAINER_NAME"
echo "Primary Domain: $PRIMARY_DOMAIN"
echo "Certificate Path: $CERT_SOURCE_DIR"
echo ""

# Check if container is running
if ! docker ps | grep -q "$CERTBOT_CONTAINER_NAME"; then
    echo "❌ Certbot container '$CERTBOT_CONTAINER_NAME' is not running"
    exit 1
fi

echo "✅ Certbot container is running"

# Test certificate files exist
echo "Testing certificate files..."
if docker exec "$CERTBOT_CONTAINER_NAME" test -f "$CERT_SOURCE_DIR/cert.pem"; then
    echo "✅ cert.pem exists"
else
    echo "❌ cert.pem not found"
    exit 1
fi

if docker exec "$CERTBOT_CONTAINER_NAME" test -f "$CERT_SOURCE_DIR/privkey.pem"; then
    echo "✅ privkey.pem exists"
else
    echo "❌ privkey.pem not found"
    exit 1
fi

if docker exec "$CERTBOT_CONTAINER_NAME" test -f "$CERT_SOURCE_DIR/fullchain.pem"; then
    echo "✅ fullchain.pem exists"
else
    echo "❌ fullchain.pem not found"
    exit 1
fi

echo ""
echo "=== Certificate Information ==="
docker exec "$CERTBOT_CONTAINER_NAME" openssl x509 -in "$CERT_SOURCE_DIR/cert.pem" -noout -text | grep -E "(Subject:|Issuer:|Not Before:|Not After:|DNS:)"

echo ""
echo "=== Certificate Expiration Check ==="
if docker exec "$CERTBOT_CONTAINER_NAME" openssl x509 -in "$CERT_SOURCE_DIR/cert.pem" -noout -checkend 2592000; then
    echo "✅ Certificate is valid for at least 30 more days"
else
    echo "⚠️  Certificate expires within 30 days or is already expired"
fi

echo ""
echo "=== Test Complete ==="