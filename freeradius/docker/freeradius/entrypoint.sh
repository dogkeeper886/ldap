#!/bin/bash
# FreeRADIUS Server Entrypoint Script
# Purpose: Configure and start FreeRADIUS server with TLS support

set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[FreeRADIUS][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[FreeRADIUS][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[FreeRADIUS][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[FreeRADIUS][$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Configuration
RADIUS_DOMAIN=${RADIUS_DOMAIN:-radius.example.com}
ENABLE_TLS=${ENABLE_TLS:-true}
TLS_CERT_FILE=${TLS_CERT_FILE:-cert.pem}
TLS_KEY_FILE=${TLS_KEY_FILE:-privkey.pem}
TLS_CA_FILE=${TLS_CA_FILE:-fullchain.pem}
FREERADIUS_LOG_LEVEL=${FREERADIUS_LOG_LEVEL:-info}

# Paths (Alpine uses /etc/raddb/)
CONFIG_DIR="/etc/raddb"
CERT_DIR="$CONFIG_DIR/certs"
LOG_DIR="/var/log/freeradius"

# Initialize logging
init_logging() {
    log "Starting FreeRADIUS server initialization"
    log "Domain: $RADIUS_DOMAIN"
    log "TLS Enabled: $ENABLE_TLS"
    log "Log Level: $FREERADIUS_LOG_LEVEL"
    log "Certificate directory: $CERT_DIR"
}

# Check certificate files
check_certificates() {
    if [ "$ENABLE_TLS" = "true" ]; then
        log "Checking TLS certificates..."

        local cert_files=("$TLS_CERT_FILE" "$TLS_KEY_FILE" "$TLS_CA_FILE")
        for cert_file in "${cert_files[@]}"; do
            if [ ! -f "$CERT_DIR/$cert_file" ]; then
                error "Certificate file not found: $CERT_DIR/$cert_file"
                error "Please ensure certificates are copied to the build context"
                return 1
            fi
        done

        log "✓ All certificate files are present"

        # Check certificate validity
        if openssl x509 -in "$CERT_DIR/$TLS_CERT_FILE" -noout -checkend 0 >/dev/null 2>&1; then
            local expiry_date
            expiry_date=$(openssl x509 -in "$CERT_DIR/$TLS_CERT_FILE" -noout -enddate | cut -d= -f2)
            log "✓ Certificate is valid until: $expiry_date"
        else
            warn "Certificate may be expired or invalid"
        fi
    else
        info "TLS is disabled, skipping certificate checks"
    fi
}

# Configure TLS settings
configure_tls() {
    if [ "$ENABLE_TLS" = "true" ]; then
        log "Configuring TLS settings..."

        # Run TLS setup script
        /opt/radius-scripts/setup-tls.sh

        log "✓ TLS configuration completed"
    else
        info "TLS is disabled, skipping TLS configuration"
    fi
}

# Setup test users with environment passwords
setup_test_users() {
    log "Setting up test users with environment passwords..."

    # Update user passwords from environment variables (Alpine uses 'authorize' file)
    local users_file="$CONFIG_DIR/mods-config/files/authorize"

    if [ -f "$users_file" ]; then
        # Replace password placeholders with actual values
        sed -i "s/{{TEST_USER_PASSWORD}}/${TEST_USER_PASSWORD:-testpass123}/g" "$users_file"
        sed -i "s/{{GUEST_USER_PASSWORD}}/${GUEST_USER_PASSWORD:-guestpass123}/g" "$users_file"
        sed -i "s/{{ADMIN_USER_PASSWORD}}/${ADMIN_USER_PASSWORD:-adminpass123}/g" "$users_file"
        sed -i "s/{{CONTRACTOR_PASSWORD}}/${CONTRACTOR_PASSWORD:-contractorpass123}/g" "$users_file"
        sed -i "s/{{VIP_PASSWORD}}/${VIP_PASSWORD:-vippass123}/g" "$users_file"

        log "✓ Test user passwords configured"
    else
        warn "Users file not found at $users_file"
    fi
}

# Signal handlers for graceful shutdown
setup_signal_handlers() {
    log "Setting up signal handlers..."

    # Function to handle shutdown signals
    shutdown_handler() {
        log "Received shutdown signal, stopping FreeRADIUS gracefully..."

        # Kill any running FreeRADIUS processes
        if pgrep -f radiusd >/dev/null; then
            log "Stopping FreeRADIUS processes..."
            pkill -TERM -f radiusd || true
            sleep 5
            pkill -KILL -f radiusd >/dev/null 2>&1 || true
        fi

        log "FreeRADIUS shutdown complete"
        exit 0
    }

    # Trap signals
    trap shutdown_handler SIGTERM SIGINT SIGQUIT
}

# Main initialization
main() {
    init_logging
    setup_signal_handlers

    check_certificates
    configure_tls
    setup_test_users

    log "FreeRADIUS server initialization completed successfully"
    log "Starting FreeRADIUS server..."

    # Execute the command passed to the container
    exec "$@"
}

# Run main function with all arguments
main "$@"
