#!/bin/bash
# Certbot Custom Entrypoint Script
# Purpose: Manage Let's Encrypt certificates with automated renewal

set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[Certbot][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> /opt/certbot-logs/certbot.log
}

error() {
    echo -e "${RED}[Certbot][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >> /opt/certbot-logs/certbot.log
}

warn() {
    echo -e "${YELLOW}[Certbot][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1" >> /opt/certbot-logs/certbot.log
}

info() {
    echo -e "${BLUE}[Certbot][$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1" >> /opt/certbot-logs/certbot.log
}

# Global variables
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
RENEWAL_INTERVAL=${RENEWAL_INTERVAL:-43200}  # 12 hours default
DRY_RUN=${DRY_RUN:-false}
STAGING=${STAGING:-false}

# Initialize logging
init_logging() {
    log "Starting Certbot container initialization"
    log "Domain: ${DOMAIN:-not-set}"
    log "Email: ${EMAIL:-not-set}"
    log "Environment: ${ENVIRONMENT:-development}"
    log "Renewal interval: ${RENEWAL_INTERVAL}s"
    log "Dry run mode: $DRY_RUN"
    log "Staging mode: $STAGING"
}

# Validate environment variables
validate_environment() {
    log "Validating environment configuration..."
    
    local errors=()
    
    # Check required variables
    if [ -z "${DOMAIN:-}" ]; then
        errors+=("DOMAIN is required")
    fi
    
    if [ -z "${EMAIL:-}" ]; then
        errors+=("EMAIL is required")
    fi
    
    # Validate domain format
    if [ -n "${DOMAIN:-}" ] && [[ ! "${DOMAIN}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        errors+=("DOMAIN format is invalid")
    fi
    
    # Validate email format
    if [ -n "${EMAIL:-}" ] && [[ ! "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        errors+=("EMAIL format is invalid")
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

# Check DNS resolution
check_dns_resolution() {
    log "Checking DNS resolution for $DOMAIN..."
    
    # Try to resolve the domain
    if nslookup "$DOMAIN" >/dev/null 2>&1; then
        local resolved_ip
        resolved_ip=$(nslookup "$DOMAIN" | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "unknown")
        log "Domain $DOMAIN resolves to: $resolved_ip"
        return 0
    else
        warn "DNS resolution failed for $DOMAIN"
        if [ "${ENVIRONMENT:-development}" = "production" ]; then
            error "DNS resolution is required in production"
            return 1
        else
            warn "Continuing without DNS resolution in development"
            return 0
        fi
    fi
}

# Check if certificates already exist
check_existing_certificates() {
    log "Checking for existing certificates..."
    
    if [ -d "$CERT_DIR" ] && [ -f "$CERT_DIR/cert.pem" ]; then
        log "Existing certificates found for $DOMAIN"
        
        # Check certificate validity
        if openssl x509 -in "$CERT_DIR/cert.pem" -noout -checkend 2592000 >/dev/null 2>&1; then
            local expiry_date
            expiry_date=$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -enddate | cut -d= -f2)
            log "Certificates are valid until: $expiry_date"
            fix_certificate_permissions
            return 0
        else
            warn "Existing certificates are expired or expiring soon"
            return 1
        fi
    else
        log "No existing certificates found"
        return 1
    fi
}

# Fix permissions for existing certificates
fix_certificate_permissions() {
    log "Fixing certificate permissions for cross-container access..."
    
    # Fix parent directories
    chmod 755 /etc/letsencrypt 2>/dev/null || true
    chmod 755 /etc/letsencrypt/live 2>/dev/null || true
    chmod 755 /etc/letsencrypt/archive 2>/dev/null || true
    
    # Fix domain-specific directories and files
    if [ -d "/etc/letsencrypt/archive/$DOMAIN" ]; then
        chmod 755 "/etc/letsencrypt/archive/$DOMAIN" 2>/dev/null || true
        chmod 644 "/etc/letsencrypt/archive/$DOMAIN"/*.pem 2>/dev/null || true
        chmod 640 "/etc/letsencrypt/archive/$DOMAIN/privkey"*.pem 2>/dev/null || true
    fi
    
    if [ -d "$CERT_DIR" ]; then
        chmod 755 "$CERT_DIR" 2>/dev/null || true
        # Note: symlinks don't need chmod, they inherit from target
    fi
    
    log "Certificate permissions fixed"
}

# Acquire initial certificates
acquire_certificates() {
    log "Acquiring certificates for $DOMAIN..."
    
    # Build certbot command
    local certbot_cmd="certbot certonly"
    local certbot_args=(
        "--standalone"
        "--non-interactive"
        "--agree-tos"
        "--email" "$EMAIL"
        "--domains" "$DOMAIN"
        "--rsa-key-size" "4096"
        "--keep-until-expiring"
    )
    
    # Add staging flag if in development or explicitly set
    if [ "$STAGING" = "true" ] || [ "${ENVIRONMENT:-development}" = "development" ]; then
        certbot_args+=("--staging")
        log "Using Let's Encrypt staging server"
    fi
    
    # Add dry run flag if set
    if [ "$DRY_RUN" = "true" ]; then
        certbot_args+=("--dry-run")
        log "Running in dry-run mode"
    fi
    
    # Execute certbot (run as certbot user if we're root)
    log "Executing: $certbot_cmd ${certbot_args[*]}"
    
    local success=false
    if [ "$(id -u)" = "0" ]; then
        # Running as root, execute certbot as certbot user
        if su certbot -c "$certbot_cmd ${certbot_args[*]}"; then
            success=true
        fi
    else
        # Already running as certbot user
        if $certbot_cmd "${certbot_args[@]}"; then
            success=true
        fi
    fi
    
    if [ "$success" = "true" ]; then
        log "Certificate acquisition successful"
        
        # Set proper permissions for OpenLDAP access (user 911)
        if [ -d "$CERT_DIR" ] && [ "$DRY_RUN" != "true" ]; then
            # Fix parent directories
            chmod 755 /etc/letsencrypt || true
            chmod 755 /etc/letsencrypt/live || true
            chmod 755 /etc/letsencrypt/archive || true
            chmod 755 "/etc/letsencrypt/archive/$DOMAIN" || true
            # Fix domain directory and files
            chmod 755 "$CERT_DIR"
            chmod 644 "$CERT_DIR"/*.pem || true
            chmod 644 "$CERT_DIR"/../../archive/"$DOMAIN"/*.pem || true
            # Keep private key secure but readable
            chmod 640 "$CERT_DIR/privkey.pem" || true
            chmod 640 "/etc/letsencrypt/archive/$DOMAIN/privkey"*.pem || true
            log "Certificate permissions set for cross-container access"
        fi
        
        return 0
    else
        error "Certificate acquisition failed"
        return 1
    fi
}

# Renewal loop
run_renewal_loop() {
    log "Starting certificate renewal loop (interval: ${RENEWAL_INTERVAL}s)"
    
    while true; do
        log "Running certificate renewal check..."
        
        if /opt/certbot-scripts/renew-certificates.sh; then
            log "Certificate renewal check completed successfully"
        else
            error "Certificate renewal check failed"
        fi
        
        log "Sleeping for ${RENEWAL_INTERVAL}s until next renewal check..."
        sleep "$RENEWAL_INTERVAL"
    done
}

# Signal handlers for graceful shutdown
setup_signal_handlers() {
    log "Setting up signal handlers..."
    
    # Function to handle shutdown signals
    shutdown_handler() {
        log "Received shutdown signal, stopping Certbot gracefully..."
        
        # Kill any running certbot processes
        if pgrep certbot >/dev/null; then
            log "Stopping running certbot processes..."
            pkill -TERM certbot || true
            sleep 5
            pkill -KILL certbot >/dev/null 2>&1 || true
        fi
        
        log "Certbot shutdown complete"
        exit 0
    }
    
    # Trap signals
    trap shutdown_handler SIGTERM SIGINT SIGQUIT
}

# Initial certificate acquisition mode
run_initial_acquisition() {
    log "Running initial certificate acquisition mode"
    
    validate_environment
    check_dns_resolution
    
    if check_existing_certificates; then
        log "Valid certificates already exist, skipping acquisition"
        exit 0
    else
        log "Acquiring new certificates..."
        if acquire_certificates; then
            log "Initial certificate acquisition completed successfully"
            exit 0
        else
            error "Initial certificate acquisition failed"
            exit 1
        fi
    fi
}

# One-time renewal mode
run_renewal() {
    log "Running one-time certificate renewal"
    
    if /opt/certbot-scripts/renew-certificates.sh; then
        log "Certificate renewal completed successfully"
        exit 0
    else
        error "Certificate renewal failed"
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo "Certbot Container Usage:"
    echo "  renew-loop          - Run continuous renewal loop (default)"
    echo "  acquire            - Acquire initial certificates and exit"
    echo "  renew              - Run one-time renewal and exit"
    echo "  check              - Check certificate status and exit"
    echo ""
    echo "Environment Variables:"
    echo "  DOMAIN             - Domain name for certificates (required)"
    echo "  EMAIL              - Email for Let's Encrypt account (required)"
    echo "  ENVIRONMENT        - Environment: development or production"
    echo "  RENEWAL_INTERVAL   - Renewal check interval in seconds (default: 43200)"
    echo "  DRY_RUN           - Run in dry-run mode (true/false)"
    echo "  STAGING           - Use staging server (true/false)"
}

# Main entrypoint logic
main() {
    local command="${1:-renew-loop}"
    
    case "$command" in
        "renew-loop")
            init_logging
            validate_environment
            setup_signal_handlers
            check_dns_resolution
            
            # Fix permissions for existing certificates first
            if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
                fix_certificate_permissions
            fi
            
            # Try to acquire certificates if they don't exist
            if ! check_existing_certificates; then
                log "No valid certificates found, acquiring initial certificates..."
                acquire_certificates || warn "Initial certificate acquisition failed, will retry in renewal loop"
            fi
            
            run_renewal_loop
            ;;
        "acquire")
            init_logging
            run_initial_acquisition
            ;;
        "renew")
            init_logging
            validate_environment
            run_renewal
            ;;
        "check")
            init_logging
            /opt/certbot-scripts/check-certificates.sh
            ;;
        "--help"|"-h"|"help")
            show_usage
            exit 0
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"