#!/bin/bash
# Certificate Download Script for OpenLDAP
# Purpose: Download certificates from certbot HTTP server

set -euo pipefail

# Colors for logging
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[CertDownload][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[CertDownload][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[CertDownload][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Configuration
CERTBOT_HTTP_URL="http://certbot:8080"
TARGET_DIR="/container/service/slapd/assets/certs"
MAX_RETRIES=10
RETRY_DELAY=5

# Ensure target directory exists
setup_target_directory() {
    log "Setting up target directory: $TARGET_DIR"
    
    mkdir -p "$TARGET_DIR"
    
    # Set proper ownership (OpenLDAP user)
    chown -R openldap:openldap "$TARGET_DIR" 2>/dev/null || true
    
    log "Target directory ready"
}

# Wait for certbot HTTP server to be available
wait_for_certbot() {
    log "Waiting for certbot HTTP server to be available..."
    
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        log "Attempt $attempt/$MAX_RETRIES: Checking certbot HTTP server..."
        
        if curl -s --connect-timeout 5 "$CERTBOT_HTTP_URL/status.json" >/dev/null 2>&1; then
            log "Certbot HTTP server is available"
            
            # Show server status
            local status
            status=$(curl -s "$CERTBOT_HTTP_URL/status.json" 2>/dev/null || echo '{"error":"failed to fetch status"}')
            log "Server status: $status"
            
            return 0
        fi
        
        warn "Certbot HTTP server not available, waiting ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
        ((attempt++))
    done
    
    error "Certbot HTTP server is not available after $MAX_RETRIES attempts"
    return 1
}

# Download a certificate file
download_certificate_file() {
    local filename="$1"
    local target_path="$TARGET_DIR/$filename"
    local url="$CERTBOT_HTTP_URL/$filename"
    
    log "Downloading $filename from certbot..."
    
    local temp_file
    temp_file=$(mktemp)
    
    if curl -s --fail --connect-timeout 10 --max-time 30 "$url" -o "$temp_file"; then
        # Verify it's a valid certificate file
        if [[ "$filename" == *.pem ]]; then
            if openssl x509 -in "$temp_file" -noout -text >/dev/null 2>&1 || \
               openssl rsa -in "$temp_file" -noout -text >/dev/null 2>&1 || \
               openssl crl -in "$temp_file" -noout -text >/dev/null 2>&1; then
                
                # Move to target location
                mv "$temp_file" "$target_path"
                
                # Set proper permissions
                chown openldap:openldap "$target_path" 2>/dev/null || true
                chmod 644 "$target_path"
                
                log "Successfully downloaded: $filename"
                return 0
            else
                error "Downloaded file $filename is not a valid certificate"
                rm -f "$temp_file"
                return 1
            fi
        else
            # Non-certificate file, just move it
            mv "$temp_file" "$target_path"
            chown openldap:openldap "$target_path" 2>/dev/null || true
            chmod 644 "$target_path"
            
            log "Successfully downloaded: $filename"
            return 0
        fi
    else
        error "Failed to download $filename from $url"
        rm -f "$temp_file"
        return 1
    fi
}

# Download all certificate files
download_certificates() {
    log "Starting certificate download from certbot HTTP server..."
    
    local files=("cert.pem" "privkey.pem" "fullchain.pem")
    local success=true
    
    for file in "${files[@]}"; do
        if download_certificate_file "$file"; then
            log "✓ $file downloaded successfully"
        else
            error "✗ Failed to download $file"
            success=false
        fi
    done
    
    if [ "$success" = true ]; then
        log "All certificate files downloaded successfully"
        
        # Verify certificate validity
        verify_certificates
        
        return 0
    else
        error "Some certificate downloads failed"
        return 1
    fi
}

# Verify downloaded certificates
verify_certificates() {
    log "Verifying downloaded certificates..."
    
    local cert_file="$TARGET_DIR/cert.pem"
    local key_file="$TARGET_DIR/privkey.pem"
    local chain_file="$TARGET_DIR/fullchain.pem"
    
    # Check if files exist
    for file in "$cert_file" "$key_file" "$chain_file"; do
        if [ ! -f "$file" ]; then
            error "Certificate file missing: $file"
            return 1
        fi
    done
    
    # Verify certificate format
    if ! openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1; then
        error "Invalid certificate format: $cert_file"
        return 1
    fi
    
    # Verify private key format
    if ! openssl rsa -in "$key_file" -noout -text >/dev/null 2>&1; then
        error "Invalid private key format: $key_file"
        return 1
    fi
    
    # Check certificate expiration
    local expiry_date
    expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    log "Certificate expires: $expiry_date"
    
    # Check if certificate is not expired
    if ! openssl x509 -in "$cert_file" -noout -checkend 86400 >/dev/null 2>&1; then
        error "Certificate is expired or expires within 24 hours"
        return 1
    fi
    
    # Check if private key matches certificate
    local cert_modulus
    local key_modulus
    
    cert_modulus=$(openssl x509 -in "$cert_file" -noout -modulus 2>/dev/null || echo "")
    key_modulus=$(openssl rsa -in "$key_file" -noout -modulus 2>/dev/null || echo "")
    
    if [ -n "$cert_modulus" ] && [ -n "$key_modulus" ] && [ "$cert_modulus" = "$key_modulus" ]; then
        log "Certificate and private key match"
    else
        error "Certificate and private key do not match"
        return 1
    fi
    
    log "Certificate verification successful"
    return 0
}

# Show certificate information
show_certificate_info() {
    local cert_file="$TARGET_DIR/cert.pem"
    
    if [ -f "$cert_file" ]; then
        log "Certificate Information:"
        
        # Subject
        local subject
        subject=$(openssl x509 -in "$cert_file" -noout -subject | cut -d= -f2-)
        log "  Subject: $subject"
        
        # Issuer
        local issuer
        issuer=$(openssl x509 -in "$cert_file" -noout -issuer | cut -d= -f2-)
        log "  Issuer: $issuer"
        
        # Validity dates
        local not_before not_after
        not_before=$(openssl x509 -in "$cert_file" -noout -startdate | cut -d= -f2)
        not_after=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        log "  Valid From: $not_before"
        log "  Valid Until: $not_after"
        
        # Subject Alternative Names
        local san
        san=$(openssl x509 -in "$cert_file" -noout -text | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^[[:space:]]*//' || echo "None")
        log "  SAN: $san"
    else
        warn "Certificate file not found: $cert_file"
    fi
}

# Monitor for certificate updates
monitor_certificate_updates() {
    log "Starting certificate update monitor..."
    
    while true; do
        log "Checking for certificate updates..."
        
        # Check if certificates have been updated on the server
        local server_status
        if server_status=$(curl -s --connect-timeout 5 "$CERTBOT_HTTP_URL/status.json" 2>/dev/null); then
            log "Server status: $server_status"
            
            # Download updated certificates if available
            if download_certificates; then
                log "Certificate update check completed successfully"
            else
                warn "Certificate update failed"
            fi
        else
            warn "Unable to check certificate server status"
        fi
        
        # Check every 5 minutes
        sleep 300
    done
}

# Main function
main() {
    local action="${1:-download}"
    
    case "$action" in
        "download")
            log "Starting certificate download process..."
            
            setup_target_directory
            
            if wait_for_certbot; then
                if download_certificates; then
                    show_certificate_info
                    log "Certificate download completed successfully"
                    exit 0
                else
                    error "Certificate download failed"
                    exit 1
                fi
            else
                error "Could not connect to certbot server"
                exit 1
            fi
            ;;
        "monitor")
            log "Starting certificate monitor mode..."
            setup_target_directory
            wait_for_certbot
            monitor_certificate_updates
            ;;
        "info")
            show_certificate_info
            ;;
        "verify")
            if verify_certificates; then
                log "Certificate verification passed"
                exit 0
            else
                error "Certificate verification failed"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [download|monitor|info|verify]"
            echo "  download - Download certificates once and exit (default)"
            echo "  monitor  - Download certificates and monitor for updates"
            echo "  info     - Show certificate information"
            echo "  verify   - Verify existing certificates"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"