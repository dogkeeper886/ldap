#!/bin/bash
# OpenLDAP Custom Entrypoint Script
# Purpose: Initialize OpenLDAP with custom configuration and certificate management

set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[OpenLDAP][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[OpenLDAP][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[OpenLDAP][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[OpenLDAP][$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Global variables
CERT_DIR="/etc/letsencrypt/live/${LDAP_DOMAIN}"
LDAP_BASE_DN="dc=${LDAP_DOMAIN//./,dc=}"
FIRST_RUN_FLAG="/var/lib/ldap/.ldap-initialized"

# Initialize logging
init_logging() {
    log "Starting OpenLDAP container initialization"
    log "Domain: ${LDAP_DOMAIN:-not-set}"
    log "Organization: ${LDAP_ORGANISATION:-not-set}"
    log "TLS: ${LDAP_TLS:-false}"
    log "Base DN: $LDAP_BASE_DN"
}

# Wait for certificates to be available
wait_for_certificates() {
    if [ "${LDAP_TLS:-false}" = "true" ]; then
        log "Waiting for TLS certificates..."
        
        local max_attempts=60
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if [ -f "$CERT_DIR/cert.pem" ] && \
               [ -f "$CERT_DIR/privkey.pem" ] && \
               [ -f "$CERT_DIR/fullchain.pem" ]; then
                log "TLS certificates found"
                
                # Verify certificate validity
                if openssl x509 -in "$CERT_DIR/cert.pem" -noout -checkend 0 >/dev/null 2>&1; then
                    log "Certificate validation successful"
                    break
                else
                    warn "Certificate validation failed, but continuing..."
                    break
                fi
            fi
            
            info "Attempt $attempt/$max_attempts: Waiting for certificates..."
            sleep 5
            ((attempt++))
        done
        
        if [ $attempt -gt $max_attempts ]; then
            warn "Certificates not found after $max_attempts attempts"
            if [ "${ENVIRONMENT:-development}" = "production" ]; then
                error "Cannot start in production without valid certificates"
                exit 1
            else
                warn "Continuing without certificates in development mode"
            fi
        fi
        
        # Set proper certificate permissions
        if [ -f "$CERT_DIR/cert.pem" ]; then
            chmod 644 "$CERT_DIR/cert.pem" "$CERT_DIR/fullchain.pem" || true
            chmod 600 "$CERT_DIR/privkey.pem" || true
            log "Certificate permissions set"
        fi
    else
        log "TLS disabled, skipping certificate check"
    fi
}

# Initialize LDAP database and structure
init_ldap_database() {
    log "Initializing LDAP database..."
    
    # Check if this is the first run
    if [ ! -f "$FIRST_RUN_FLAG" ]; then
        log "First run detected, running initialization script"
        
        # Run custom initialization in background after LDAP starts
        /opt/ldap-scripts/init-ldap.sh &
        
        # Mark as initialized
        touch "$FIRST_RUN_FLAG"
        log "LDAP initialization flag created"
    else
        log "LDAP already initialized, skipping database setup"
    fi
}

# Configure LDAP logging
configure_logging() {
    log "Configuring LDAP logging..."
    
    # Set log level based on environment
    if [ "${ENVIRONMENT:-development}" = "development" ]; then
        export LDAP_LOG_LEVEL=${LDAP_LOG_LEVEL:-256}  # More verbose in dev
    else
        export LDAP_LOG_LEVEL=${LDAP_LOG_LEVEL:-32}   # Less verbose in prod
    fi
    
    log "Log level set to: $LDAP_LOG_LEVEL"
}

# Health check setup
setup_health_monitoring() {
    log "Setting up health monitoring..."
    
    # Create health check endpoint
    cat > /opt/ldap-health/status.txt << EOF
OpenLDAP Health Status
Started: $(date)
Domain: ${LDAP_DOMAIN:-not-set}
Base DN: $LDAP_BASE_DN
TLS: ${LDAP_TLS:-false}
Environment: ${ENVIRONMENT:-development}
EOF
    
    log "Health monitoring configured"
}

# Signal handlers for graceful shutdown
setup_signal_handlers() {
    log "Setting up signal handlers..."
    
    # Function to handle shutdown signals
    shutdown_handler() {
        log "Received shutdown signal, stopping OpenLDAP gracefully..."
        
        # Stop slapd if running
        if pgrep slapd >/dev/null; then
            pkill -TERM slapd
            
            # Wait for graceful shutdown
            local attempts=10
            while [ $attempts -gt 0 ] && pgrep slapd >/dev/null; do
                sleep 1
                ((attempts--))
            done
            
            # Force kill if still running
            if pgrep slapd >/dev/null; then
                warn "Force killing slapd"
                pkill -KILL slapd
            fi
        fi
        
        log "OpenLDAP shutdown complete"
        exit 0
    }
    
    # Trap signals
    trap shutdown_handler SIGTERM SIGINT SIGQUIT
}

# Validate environment variables
validate_environment() {
    log "Validating environment configuration..."
    
    local errors=()
    
    # Check required variables
    if [ -z "${LDAP_DOMAIN:-}" ]; then
        errors+=("LDAP_DOMAIN is required")
    fi
    
    if [ -z "${LDAP_ADMIN_PASSWORD:-}" ]; then
        errors+=("LDAP_ADMIN_PASSWORD is required")
    fi
    
    if [ -z "${LDAP_ORGANISATION:-}" ]; then
        errors+=("LDAP_ORGANISATION is required")
    fi
    
    # Validate domain format
    if [ -n "${LDAP_DOMAIN:-}" ] && [[ ! "${LDAP_DOMAIN}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        errors+=("LDAP_DOMAIN format is invalid")
    fi
    
    # Check password strength
    if [ -n "${LDAP_ADMIN_PASSWORD:-}" ] && [ ${#LDAP_ADMIN_PASSWORD} -lt 8 ]; then
        errors+=("LDAP_ADMIN_PASSWORD must be at least 8 characters")
    fi
    
    if [ ${#errors[@]} -gt 0 ]; then
        error "Environment validation failed:"
        for err in "${errors[@]}"; do
            error "  - $err"
        done
        exit 1
    fi
    
    log "Environment validation passed"
}

# Pre-startup checks
pre_startup_checks() {
    log "Running pre-startup checks..."
    
    # Check disk space
    local disk_usage
    disk_usage=$(df /var/lib/ldap | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt 90 ]; then
        error "Disk usage critical: ${disk_usage}%"
        exit 1
    elif [ "$disk_usage" -gt 80 ]; then
        warn "Disk usage high: ${disk_usage}%"
    fi
    
    # Check memory
    local mem_available
    mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    local mem_available_mb=$((mem_available / 1024))
    
    if [ "$mem_available_mb" -lt 100 ]; then
        warn "Low memory available: ${mem_available_mb}MB"
    fi
    
    log "Pre-startup checks completed"
}

# Main entrypoint logic
main() {
    init_logging
    validate_environment
    setup_signal_handlers
    pre_startup_checks
    configure_logging
    setup_health_monitoring
    wait_for_certificates
    init_ldap_database
    
    log "OpenLDAP container initialization complete"
    log "Starting OpenLDAP service..."
    
    # Execute the original OpenLDAP entrypoint with provided arguments
    exec /container/tool/run "$@"
}

# Run main function
main "$@"