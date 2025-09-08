#!/bin/bash
# Script to copy certificates from external standalone certbot container to OpenLDAP build context

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
EXTERNAL_CERTBOT_CONTAINER="standalone-certbot"
PRIMARY_DOMAIN=${LDAP_DOMAIN:-ldap.example.com}
CERT_SOURCE_DIR="/etc/letsencrypt/live/${PRIMARY_DOMAIN}"
CERT_DEST_DIR="./docker/certs"

log "Copying certificates from external standalone certbot container..."
log "Container: $EXTERNAL_CERTBOT_CONTAINER"
log "Domain: $PRIMARY_DOMAIN"
log "Source: $CERT_SOURCE_DIR"
log "Destination: $CERT_DEST_DIR"

# Check if external certbot container is running
if ! docker ps | grep -q "$EXTERNAL_CERTBOT_CONTAINER"; then
    error "External certbot container '$EXTERNAL_CERTBOT_CONTAINER' is not running"
    error "Please start the standalone certbot service first:"
    error "  cd ../certbot && make deploy"
    exit 1
fi

# Create certs directory in OpenLDAP build context
mkdir -p "$CERT_DEST_DIR"

# Copy certificates from external certbot container
log "Copying certificate files..."
docker cp "$EXTERNAL_CERTBOT_CONTAINER:$CERT_SOURCE_DIR/cert.pem" "$CERT_DEST_DIR/cert.pem"
docker cp "$EXTERNAL_CERTBOT_CONTAINER:$CERT_SOURCE_DIR/privkey.pem" "$CERT_DEST_DIR/privkey.pem"  
docker cp "$EXTERNAL_CERTBOT_CONTAINER:$CERT_SOURCE_DIR/fullchain.pem" "$CERT_DEST_DIR/fullchain.pem"

# Set appropriate permissions
chmod 644 "$CERT_DEST_DIR/cert.pem" "$CERT_DEST_DIR/fullchain.pem"
chmod 640 "$CERT_DEST_DIR/privkey.pem"

# Verify certificates were copied
if [[ -f "$CERT_DEST_DIR/cert.pem" ]] && [[ -f "$CERT_DEST_DIR/privkey.pem" ]] && [[ -f "$CERT_DEST_DIR/fullchain.pem" ]]; then
    log "Certificates copied successfully:"
    ls -la "$CERT_DEST_DIR/"
    
    # Show certificate expiration
    log "Certificate expiration info:"
    openssl x509 -in "$CERT_DEST_DIR/cert.pem" -noout -dates
else
    error "Failed to copy certificates"
    exit 1
fi

log "Certificates ready for OpenLDAP Docker build"