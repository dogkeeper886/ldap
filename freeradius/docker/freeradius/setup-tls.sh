#!/bin/bash
# FreeRADIUS TLS Configuration Setup Script

set -euo pipefail

# Colors for logging
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[TLS-Setup][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[TLS-Setup][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Configuration
CONFIG_DIR="/etc/freeradius/3.0"
CERT_DIR="$CONFIG_DIR/certs"
TLS_CERT_FILE=${TLS_CERT_FILE:-cert.pem}
TLS_KEY_FILE=${TLS_KEY_FILE:-privkey.pem}
TLS_CA_FILE=${TLS_CA_FILE:-fullchain.pem}

log "Configuring FreeRADIUS TLS settings"
log "Certificate directory: $CERT_DIR"
log "Certificate file: $TLS_CERT_FILE"
log "Private key file: $TLS_KEY_FILE"
log "CA file: $TLS_CA_FILE"

# Update EAP module configuration for TLS
EAP_CONFIG="$CONFIG_DIR/mods-available/eap"

if [ -f "$EAP_CONFIG" ]; then
    log "Updating EAP configuration for TLS certificates..."
    
    # Update certificate paths in EAP configuration
    sed -i "s|certificate_file = .*|certificate_file = \${certdir}/$TLS_CERT_FILE|g" "$EAP_CONFIG"
    sed -i "s|private_key_file = .*|private_key_file = \${certdir}/$TLS_KEY_FILE|g" "$EAP_CONFIG"
    sed -i "s|ca_file = .*|ca_file = \${certdir}/$TLS_CA_FILE|g" "$EAP_CONFIG"
    
    log "✓ EAP configuration updated"
else
    warn "EAP configuration file not found at $EAP_CONFIG"
fi

# Set proper permissions on certificate files
log "Setting certificate file permissions..."
chmod 600 "$CERT_DIR"/*.pem || true
chmod 644 "$CERT_DIR/$TLS_CERT_FILE" "$CERT_DIR/$TLS_CA_FILE" || true

log "TLS configuration setup completed"