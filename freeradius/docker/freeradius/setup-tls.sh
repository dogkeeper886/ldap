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

# Configuration (Alpine uses /etc/raddb/)
CONFIG_DIR="/etc/raddb"
CERT_DIR="$CONFIG_DIR/certs"
TLS_CERT_FILE=${TLS_CERT_FILE:-cert.pem}
TLS_KEY_FILE=${TLS_KEY_FILE:-privkey.pem}
TLS_CA_FILE=${TLS_CA_FILE:-fullchain.pem}

log "Configuring FreeRADIUS TLS settings"
log "Certificate directory: $CERT_DIR"
log "Certificate file: $TLS_CERT_FILE"
log "Private key file: $TLS_KEY_FILE"
log "CA file: $TLS_CA_FILE"

# Update EAP module configuration for TLS (use mods-enabled symlink)
EAP_CONFIG="$CONFIG_DIR/mods-enabled/eap"

if [ -f "$EAP_CONFIG" ]; then
    log "Updating EAP configuration for TLS certificates..."

    # Replace default certificate paths with our Let's Encrypt certificates
    # Default uses: ${certdir}/server.pem and ${cadir}/ca.pem
    sed -i "s|private_key_file = \${certdir}/server.pem|private_key_file = \${certdir}/$TLS_KEY_FILE|g" "$EAP_CONFIG"
    sed -i "s|certificate_file = \${certdir}/server.pem|certificate_file = \${certdir}/$TLS_CERT_FILE|g" "$EAP_CONFIG"
    sed -i "s|ca_file = \${cadir}/ca.pem|ca_file = \${certdir}/$TLS_CA_FILE|g" "$EAP_CONFIG"

    # Remove private_key_password since Let's Encrypt keys are not encrypted
    sed -i "s|private_key_password = .*|#private_key_password = \"\"|g" "$EAP_CONFIG"

    log "✓ EAP configuration updated"
else
    warn "EAP configuration file not found at $EAP_CONFIG"
fi

# Set proper permissions on certificate files
log "Setting certificate file permissions..."
chmod 600 "$CERT_DIR"/*.pem 2>/dev/null || true
chmod 644 "$CERT_DIR/$TLS_CERT_FILE" "$CERT_DIR/$TLS_CA_FILE" 2>/dev/null || true

log "TLS configuration setup completed"
