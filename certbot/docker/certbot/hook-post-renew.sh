#!/bin/bash
# Post-Renewal Hook Script
# Purpose: Actions to perform after successful certificate renewal

set -euo pipefail

# Colors for logging
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[PostRenew][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] POST-RENEW: $1" >> /opt/certbot-logs/certbot.log
}

error() {
    echo -e "${RED}[PostRenew][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] POST-RENEW ERROR: $1" >> /opt/certbot-logs/certbot.log
}

warn() {
    echo -e "${YELLOW}[PostRenew][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] POST-RENEW WARNING: $1" >> /opt/certbot-logs/certbot.log
}

# Verify new certificates
verify_new_certificates() {
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
    
    log "Verifying newly renewed certificates..."
    
    if [ ! -f "$cert_file" ]; then
        error "Certificate file not found after renewal"
        return 1
    fi
    
    # Check certificate validity
    if openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1; then
        local expiry_date
        expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        log "Certificate verification successful, expires: $expiry_date"
        return 0
    else
        error "Certificate verification failed"
        return 1
    fi
}

# Copy certificates to OpenLDAP directory
copy_certificates_to_ldap() {
    local source_dir="/etc/letsencrypt/live/${DOMAIN}"
    local ldap_cert_dir="/etc/letsencrypt/ldap-certs"
    
    log "Copying certificates to LDAP directory..."
    
    # Create LDAP certificate directory if it doesn't exist
    mkdir -p "$ldap_cert_dir"
    
    # Copy certificate files
    if [ -f "$source_dir/cert.pem" ] && \
       [ -f "$source_dir/privkey.pem" ] && \
       [ -f "$source_dir/fullchain.pem" ]; then
        
        cp "$source_dir/cert.pem" "$ldap_cert_dir/cert.pem"
        cp "$source_dir/privkey.pem" "$ldap_cert_dir/privkey.pem"
        cp "$source_dir/fullchain.pem" "$ldap_cert_dir/fullchain.pem"
        
        # Set proper permissions for OpenLDAP access
        chmod 644 "$ldap_cert_dir/cert.pem" "$ldap_cert_dir/fullchain.pem" "$ldap_cert_dir/privkey.pem"
        
        log "Certificates copied successfully to $ldap_cert_dir"
        return 0
    else
        error "Source certificate files not found"
        return 1
    fi
}

# Signal OpenLDAP to reload certificates
reload_openldap_certificates() {
    log "Signaling OpenLDAP to reload certificates..."
    
    # Try to find OpenLDAP container and reload it
    local openldap_container
    openldap_container=$(docker ps --filter "name=openldap" --format "{{.Names}}" 2>/dev/null | head -1 || echo "")
    
    if [ -n "$openldap_container" ]; then
        log "Found OpenLDAP container: $openldap_container"
        
        # Send SIGHUP to reload configuration
        if docker exec "$openldap_container" pkill -HUP slapd 2>/dev/null; then
            log "OpenLDAP certificate reload signal sent successfully"
            
            # Wait a moment for reload
            sleep 5
            
            # Verify LDAP is still running
            if docker exec "$openldap_container" pgrep slapd >/dev/null 2>&1; then
                log "OpenLDAP is running after certificate reload"
                return 0
            else
                warn "OpenLDAP process not found after reload"
                return 1
            fi
        else
            warn "Failed to send reload signal to OpenLDAP"
            
            # Try restarting the container as fallback
            log "Attempting to restart OpenLDAP container..."
            if docker restart "$openldap_container" >/dev/null 2>&1; then
                log "OpenLDAP container restarted successfully"
                return 0
            else
                error "Failed to restart OpenLDAP container"
                return 1
            fi
        fi
    else
        warn "OpenLDAP container not found, cannot reload certificates"
        return 1
    fi
}

# Test LDAPS connection with new certificates
test_ldaps_connection() {
    log "Testing LDAPS connection with new certificates..."
    
    # Wait for OpenLDAP to be ready
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if echo "Q" | timeout 5 openssl s_client -connect "${DOMAIN}:636" >/dev/null 2>&1; then
            log "LDAPS connection test successful"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts: LDAPS not ready yet, waiting..."
        sleep 3
        ((attempt++))
    done
    
    warn "LDAPS connection test failed after $max_attempts attempts"
    return 1
}

# Send notification about certificate renewal
send_notification() {
    local status="$1"
    local message="$2"
    
    log "Certificate renewal notification: $status - $message"
    
    # Create notification file that can be read by monitoring systems
    cat > /tmp/cert-renewal-notification.json << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "domain": "${DOMAIN}",
  "status": "$status",
  "message": "$message",
  "environment": "${ENVIRONMENT:-development}"
}
EOF
    
    # Log notification for external monitoring
    echo "CERT_RENEWAL_EVENT: $status - $message" >> /opt/certbot-logs/certbot.log
    
    # If there's a webhook URL, send notification (optional)
    if [ -n "${NOTIFICATION_WEBHOOK:-}" ]; then
        log "Sending webhook notification to $NOTIFICATION_WEBHOOK"
        
        if curl -s -X POST \
            -H "Content-Type: application/json" \
            -d @/tmp/cert-renewal-notification.json \
            "$NOTIFICATION_WEBHOOK" >/dev/null 2>&1; then
            log "Webhook notification sent successfully"
        else
            warn "Failed to send webhook notification"
        fi
    fi
}

# Clean up old certificate files
cleanup_old_certificates() {
    log "Cleaning up old certificate files..."
    
    # Remove backup files older than 30 days
    find /etc/letsencrypt/archive -name "*.pem" -mtime +30 -delete 2>/dev/null || true
    
    # Remove old renewal logs
    find /var/log/letsencrypt -name "*.log" -mtime +30 -delete 2>/dev/null || true
    
    log "Certificate cleanup completed"
}

# Update certificate statistics
update_certificate_stats() {
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
    
    if [ -f "$cert_file" ]; then
        local expiry_date
        local expiry_epoch
        local current_epoch
        local days_left
        
        expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        # Update statistics file
        cat > /tmp/certificate-stats.json << EOF
{
  "domain": "${DOMAIN}",
  "last_renewal": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "expires": "$expiry_date",
  "days_remaining": $days_left,
  "status": "renewed"
}
EOF
        
        log "Certificate statistics updated: $days_left days remaining"
    fi
}

# Main post-renewal function
main() {
    log "Starting post-renewal hook for domain: ${DOMAIN}"
    
    local success=true
    
    # Verify new certificates
    if ! verify_new_certificates; then
        error "Certificate verification failed"
        success=false
    fi
    
    # Copy certificates to LDAP directory
    if ! copy_certificates_to_ldap; then
        error "Failed to copy certificates to LDAP directory"
        success=false
    fi
    
    # Reload OpenLDAP certificates
    if ! reload_openldap_certificates; then
        warn "Failed to reload OpenLDAP certificates"
        # Don't mark as failure, but log warning
    fi
    
    # Test LDAPS connection
    if ! test_ldaps_connection; then
        warn "LDAPS connection test failed"
        # Don't mark as failure in development
        if [ "${ENVIRONMENT:-development}" = "production" ]; then
            success=false
        fi
    fi
    
    # Update statistics
    update_certificate_stats
    
    # Clean up old files
    cleanup_old_certificates
    
    # Send notification
    if [ "$success" = true ]; then
        send_notification "SUCCESS" "Certificate renewal and OpenLDAP reload completed successfully"
        log "Post-renewal hook completed successfully"
        exit 0
    else
        send_notification "FAILURE" "Certificate renewal completed but some post-renewal actions failed"
        error "Post-renewal hook completed with errors"
        exit 1
    fi
}

# Run main function
main "$@"