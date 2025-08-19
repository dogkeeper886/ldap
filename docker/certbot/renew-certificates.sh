#!/bin/bash
# Certificate Renewal Script
# Purpose: Check and renew certificates as needed

set -euo pipefail

# Colors for logging
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[Renew][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] RENEW: $1" >> /opt/certbot-logs/certbot.log
}

error() {
    echo -e "${RED}[Renew][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] RENEW ERROR: $1" >> /opt/certbot-logs/certbot.log
}

warn() {
    echo -e "${YELLOW}[Renew][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] RENEW WARNING: $1" >> /opt/certbot-logs/certbot.log
}

# Check if renewal is needed
check_renewal_needed() {
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
    
    if [ ! -f "$cert_file" ]; then
        log "Certificate file not found, renewal needed"
        return 0  # Renewal needed
    fi
    
    # Check if certificate expires within 30 days
    if openssl x509 -in "$cert_file" -noout -checkend 2592000 >/dev/null 2>&1; then
        local expiry_date
        expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_epoch
        expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch
        current_epoch=$(date +%s)
        local days_left
        days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        log "Certificate expires in $days_left days"
        
        if [ $days_left -le 30 ]; then
            log "Certificate renewal needed (expires in $days_left days)"
            return 0  # Renewal needed
        else
            log "Certificate renewal not needed yet"
            return 1  # No renewal needed
        fi
    else
        log "Certificate is expired or expiring soon, renewal needed"
        return 0  # Renewal needed
    fi
}

# Perform certificate renewal
perform_renewal() {
    log "Starting certificate renewal process..."
    
    # Build renewal command
    local renewal_args=(
        "--non-interactive"
        "--quiet"
    )
    
    # Add staging flag if in development
    if [ "${ENVIRONMENT:-development}" = "development" ]; then
        renewal_args+=("--staging")
        log "Using staging server for renewal"
    fi
    
    # Add dry run if specified
    if [ "${DRY_RUN:-false}" = "true" ]; then
        renewal_args+=("--dry-run")
        log "Running renewal in dry-run mode"
    fi
    
    # Execute renewal
    log "Executing: certbot renew ${renewal_args[*]}"
    
    if certbot renew "${renewal_args[@]}"; then
        log "Certificate renewal completed successfully"
        
        # Run post-renewal hook
        if [ -f "/opt/certbot-scripts/hook-post-renew.sh" ]; then
            log "Running post-renewal hook..."
            if /opt/certbot-scripts/hook-post-renew.sh; then
                log "Post-renewal hook completed successfully"
            else
                warn "Post-renewal hook failed"
            fi
        fi
        
        return 0
    else
        error "Certificate renewal failed"
        return 1
    fi
}

# Verify renewed certificates
verify_renewal() {
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
    
    log "Verifying renewed certificates..."
    
    if [ ! -f "$cert_file" ]; then
        error "Certificate file not found after renewal"
        return 1
    fi
    
    # Check certificate validity
    if openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1; then
        local subject
        local issuer
        local expiry_date
        
        subject=$(openssl x509 -in "$cert_file" -noout -subject | sed 's/subject=//')
        issuer=$(openssl x509 -in "$cert_file" -noout -issuer | sed 's/issuer=//')
        expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        
        log "Certificate verification successful:"
        log "  Subject: $subject"
        log "  Issuer: $issuer"
        log "  Expires: $expiry_date"
        
        # Check if domain matches
        if openssl x509 -in "$cert_file" -noout -text | grep -q "$DOMAIN"; then
            log "Domain verification passed"
            return 0
        else
            error "Domain verification failed"
            return 1
        fi
    else
        error "Certificate verification failed"
        return 1
    fi
}

# Log renewal statistics
log_renewal_stats() {
    local cert_dir="/etc/letsencrypt/live"
    
    log "Certificate renewal statistics:"
    
    if [ -d "$cert_dir" ]; then
        local cert_count
        cert_count=$(find "$cert_dir" -name "cert.pem" | wc -l)
        log "  Total certificates: $cert_count"
        
        # List all certificates with expiry dates
        for cert_file in "$cert_dir"/*/cert.pem; do
            if [ -f "$cert_file" ]; then
                local domain_name
                local expiry_date
                
                domain_name=$(basename "$(dirname "$cert_file")")
                expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
                
                log "  $domain_name: expires $expiry_date"
            fi
        done
    else
        log "  No certificates directory found"
    fi
}

# Handle renewal errors
handle_renewal_error() {
    local error_code=$1
    
    error "Certificate renewal failed with exit code: $error_code"
    
    # Log common error scenarios
    case $error_code in
        1)
            error "General certbot error - check configuration and connectivity"
            ;;
        2)
            error "Certificate already up to date"
            ;;
        3)
            error "Too many attempts - rate limited by Let's Encrypt"
            ;;
        *)
            error "Unknown error code: $error_code"
            ;;
    esac
    
    # Check disk space
    local disk_usage
    disk_usage=$(df /etc/letsencrypt | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt 90 ]; then
        error "Disk usage critical: ${disk_usage}% - this may cause renewal failures"
    fi
    
    # Check DNS resolution
    if ! nslookup "$DOMAIN" >/dev/null 2>&1; then
        error "DNS resolution failed for $DOMAIN"
    fi
    
    # Log recent certbot logs
    if [ -f "/var/log/letsencrypt/letsencrypt.log" ]; then
        error "Recent certbot logs:"
        tail -10 /var/log/letsencrypt/letsencrypt.log 2>/dev/null | while IFS= read -r line; do
            error "  $line"
        done
    fi
}

# Main renewal function
main() {
    log "Starting certificate renewal check for domain: ${DOMAIN}"
    
    # Check if renewal is needed
    if check_renewal_needed; then
        log "Certificate renewal is needed"
        
        # Perform renewal
        if perform_renewal; then
            # Verify the renewal
            if verify_renewal; then
                log "Certificate renewal process completed successfully"
                log_renewal_stats
                return 0
            else
                error "Certificate renewal verification failed"
                return 1
            fi
        else
            handle_renewal_error $?
            return 1
        fi
    else
        log "Certificate renewal not needed at this time"
        log_renewal_stats
        return 0
    fi
}

# Run main function
main "$@"