#!/bin/bash
# Script to copy certificates from certbot container to OpenLDAP build context

set -euo pipefail

# Colors for logging
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Ensure certbot container is running
if ! docker ps | grep -q "certbot"; then
    warn "Certbot container not running. Starting certbot first..."
    docker compose up -d certbot
    sleep 10
fi

# Create certs directory in OpenLDAP build context
CERT_DIR="/home/jack_tseng/ldap/docker/openldap/certs"
mkdir -p "$CERT_DIR"

log "Copying certificates from certbot container..."

# Copy certificates from certbot container
docker cp certbot:/etc/letsencrypt/ldap-certs/cert.pem "$CERT_DIR/"
docker cp certbot:/etc/letsencrypt/ldap-certs/privkey.pem "$CERT_DIR/"  
docker cp certbot:/etc/letsencrypt/ldap-certs/fullchain.pem "$CERT_DIR/"

# Verify certificates were copied
if [[ -f "$CERT_DIR/cert.pem" ]] && [[ -f "$CERT_DIR/privkey.pem" ]] && [[ -f "$CERT_DIR/fullchain.pem" ]]; then
    log "Certificates copied successfully:"
    ls -la "$CERT_DIR/"
else
    echo "ERROR: Failed to copy certificates"
    exit 1
fi

log "Certificates ready for OpenLDAP Docker build"