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
CLIENT_CA_FILE=${CLIENT_CA_FILE:-client-ca.pem}
FREERADIUS_LOG_LEVEL=${FREERADIUS_LOG_LEVEL:-info}

# Database configuration
POSTGRES_HOST=${POSTGRES_HOST:-radius-postgres}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${POSTGRES_DB:-radius}
POSTGRES_USER=${POSTGRES_USER:-radius}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-radiuspass123}

# Paths (Alpine uses /etc/raddb/)
CONFIG_DIR="/etc/raddb"
CERT_DIR="$CONFIG_DIR/certs"
SERVER_CERT_DIR="$CERT_DIR/server"
CA_CERT_DIR="$CERT_DIR/ca"
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

        # Check server certificates
        local server_cert_files=("$TLS_CERT_FILE" "$TLS_KEY_FILE")
        for cert_file in "${server_cert_files[@]}"; do
            if [ ! -f "$SERVER_CERT_DIR/$cert_file" ]; then
                error "Server certificate file not found: $SERVER_CERT_DIR/$cert_file"
                error "Please ensure certificates are copied to the build context"
                return 1
            fi
        done

        # Check client CA certificate
        if [ ! -f "$CA_CERT_DIR/$CLIENT_CA_FILE" ]; then
            error "Client CA file not found: $CA_CERT_DIR/$CLIENT_CA_FILE"
            error "Please ensure the client CA is copied to the build context"
            return 1
        fi

        log "✓ All certificate files are present"

        # Check server certificate validity
        if openssl x509 -in "$SERVER_CERT_DIR/$TLS_CERT_FILE" -noout -checkend 0 >/dev/null 2>&1; then
            local expiry_date
            expiry_date=$(openssl x509 -in "$SERVER_CERT_DIR/$TLS_CERT_FILE" -noout -enddate | cut -d= -f2)
            log "✓ Server certificate is valid until: $expiry_date"
        else
            warn "Server certificate may be expired or invalid"
        fi

        # Check client CA certificate validity
        if openssl x509 -in "$CA_CERT_DIR/$CLIENT_CA_FILE" -noout -checkend 0 >/dev/null 2>&1; then
            local ca_expiry_date
            ca_expiry_date=$(openssl x509 -in "$CA_CERT_DIR/$CLIENT_CA_FILE" -noout -enddate | cut -d= -f2)
            log "✓ Client CA is valid until: $ca_expiry_date"
        else
            warn "Client CA may be expired or invalid"
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

    # Update clients.conf with RADIUS_SECRET
    local clients_file="$CONFIG_DIR/clients.conf"
    if [ -f "$clients_file" ]; then
        sed -i "s/{{RADIUS_SECRET}}/${RADIUS_SECRET:-testing123}/g" "$clients_file"
        log "✓ RADIUS client secret configured"
    fi
}

# Configure SQL module
configure_sql() {
    log "Configuring SQL module..."

    local sql_file="$CONFIG_DIR/mods-available/sql"
    if [ -f "$sql_file" ]; then
        sed -i "s/{{POSTGRES_HOST}}/${POSTGRES_HOST}/g" "$sql_file"
        sed -i "s/{{POSTGRES_PORT}}/${POSTGRES_PORT}/g" "$sql_file"
        sed -i "s/{{POSTGRES_DB}}/${POSTGRES_DB}/g" "$sql_file"
        sed -i "s/{{POSTGRES_USER}}/${POSTGRES_USER}/g" "$sql_file"
        sed -i "s/{{POSTGRES_PASSWORD}}/${POSTGRES_PASSWORD}/g" "$sql_file"
        log "✓ SQL module configured"
    else
        warn "SQL module config not found at $sql_file"
    fi

    # Enable SQL module by creating symlink
    if [ ! -L "$CONFIG_DIR/mods-enabled/sql" ]; then
        ln -sf ../mods-available/sql "$CONFIG_DIR/mods-enabled/sql"
        log "✓ SQL module enabled"
    fi
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    log "Waiting for PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" >/dev/null 2>&1; then
            log "✓ PostgreSQL is ready"
            return 0
        fi
        info "Attempt $attempt/$max_attempts - PostgreSQL not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done

    error "PostgreSQL did not become ready in time"
    return 1
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
    configure_sql
    wait_for_postgres

    log "FreeRADIUS server initialization completed successfully"
    log "Starting FreeRADIUS server..."

    # Execute the command passed to the container
    exec "$@"
}

# Run main function with all arguments
main "$@"
