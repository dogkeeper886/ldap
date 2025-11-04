#!/bin/bash
# Script to copy certificates from external standalone certbot container to FreeRADIUS build context

set -euo pipefail

# Colors for logging
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Configuration for external certbot
CERTBOT_CONTAINER_NAME=${EXTERNAL_CERTBOT_CONTAINER:-certbot}
# Certificate directory name in certbot (uses first domain from DOMAINS list)
CERTBOT_CERT_NAME=${LDAP_DOMAIN:-ldap.example.com}
CERTBOT_CERT_DIR="/etc/letsencrypt/live/${CERTBOT_CERT_NAME}"
FREERADIUS_CERT_DIR="./docker/freeradius/certs"

log "Copying certificates from external standalone certbot container..."
log "Certbot container: $CERTBOT_CONTAINER_NAME"
log "Certificate name: $CERTBOT_CERT_NAME"
log "Certbot cert path: $CERTBOT_CERT_DIR"
log "FreeRADIUS dest: $FREERADIUS_CERT_DIR"

# Check if external certbot container is running
if ! docker ps | grep -q "$CERTBOT_CONTAINER_NAME"; then
    error "External certbot container '$CERTBOT_CONTAINER_NAME' is not running"
    error "Please start the standalone certbot service first:"
    error "  cd ../certbot && make deploy"
    exit 1
fi

# Create certs directory in FreeRADIUS build context
mkdir -p "$FREERADIUS_CERT_DIR"

# Copy certificates from external certbot container
log "Copying certificate files..."
docker cp "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/cert.pem" "$FREERADIUS_CERT_DIR/cert.pem"
docker cp "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/privkey.pem" "$FREERADIUS_CERT_DIR/privkey.pem"
docker cp "$CERTBOT_CONTAINER_NAME:$CERTBOT_CERT_DIR/fullchain.pem" "$FREERADIUS_CERT_DIR/fullchain.pem"

# Set appropriate permissions
chmod 644 "$FREERADIUS_CERT_DIR/cert.pem" "$FREERADIUS_CERT_DIR/fullchain.pem"
chmod 640 "$FREERADIUS_CERT_DIR/privkey.pem"

# Verify certificates were copied
if [[ -f "$FREERADIUS_CERT_DIR/cert.pem" ]] && [[ -f "$FREERADIUS_CERT_DIR/privkey.pem" ]] && [[ -f "$FREERADIUS_CERT_DIR/fullchain.pem" ]]; then
    log "Certificates copied successfully:"
    ls -la "$FREERADIUS_CERT_DIR/"

    # Show certificate expiration
    log "Certificate expiration info:"
    openssl x509 -in "$FREERADIUS_CERT_DIR/cert.pem" -noout -dates

    # Show certificate domains
    log "Certificate domains:"
    openssl x509 -in "$FREERADIUS_CERT_DIR/cert.pem" -noout -text | grep -E "DNS:" | head -5
else
    error "Failed to copy certificates"
    exit 1
fi

log "Certificates ready for FreeRADIUS Docker build"
