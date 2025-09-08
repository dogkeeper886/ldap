#!/bin/bash
# Copy certificates from standalone certbot to all projects
# This script distributes certificates to LDAP and FreeRADIUS projects

set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[CertCopy][$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
    log "Loaded environment from .env"
else
    warn "No .env file found, using defaults"
fi

# Configuration
CERTBOT_CONTAINER_NAME=${CERTBOT_CONTAINER_NAME:-standalone-certbot}
PRIMARY_DOMAIN=${LDAP_DOMAIN:-ldap.example.com}
LDAP_PROJECT_PATH=${LDAP_PROJECT_PATH:-../ldap}
FREERADIUS_PROJECT_PATH=${FREERADIUS_PROJECT_PATH:-../freeradius}

# Certificate paths in certbot container
CERT_SOURCE_DIR="/etc/letsencrypt/live/${PRIMARY_DOMAIN}"

log "Starting certificate distribution to all projects"
log "Primary domain: $PRIMARY_DOMAIN"
log "Certbot container: $CERTBOT_CONTAINER_NAME"
log "LDAP project: $LDAP_PROJECT_PATH"
log "FreeRADIUS project: $FREERADIUS_PROJECT_PATH"

# Check if certbot container is running
check_certbot_container() {
    if ! docker ps | grep -q "$CERTBOT_CONTAINER_NAME"; then
        error "Certbot container '$CERTBOT_CONTAINER_NAME' is not running"
        error "Please start the certbot service first: make deploy"
        exit 1
    fi
    log "✓ Certbot container is running"
}

# Verify certificates exist in container
verify_certificates() {
    log "Verifying certificates exist in container..."
    
    if ! docker exec "$CERTBOT_CONTAINER_NAME" test -d "$CERT_SOURCE_DIR"; then
        error "Certificate directory not found in container: $CERT_SOURCE_DIR"
        exit 1
    fi
    
    local required_files=("cert.pem" "privkey.pem" "fullchain.pem")
    for file in "${required_files[@]}"; do
        if ! docker exec "$CERTBOT_CONTAINER_NAME" test -f "$CERT_SOURCE_DIR/$file"; then
            error "Required certificate file not found: $file"
            exit 1
        fi
    done
    
    log "✓ All required certificate files are present"
}

# Copy certificates to a project
copy_certs_to_project() {
    local project_name="$1"
    local project_path="$2"
    local cert_dest_dir="$3"
    
    log "Copying certificates to $project_name project..."
    
    # Check if project directory exists
    if [ ! -d "$project_path" ]; then
        error "Project directory not found: $project_path"
        return 1
    fi
    
    # Create certificate destination directory
    mkdir -p "$cert_dest_dir"
    
    # Copy certificates from container to project
    docker cp "$CERTBOT_CONTAINER_NAME:$CERT_SOURCE_DIR/cert.pem" "$cert_dest_dir/cert.pem"
    docker cp "$CERTBOT_CONTAINER_NAME:$CERT_SOURCE_DIR/privkey.pem" "$cert_dest_dir/privkey.pem"
    docker cp "$CERTBOT_CONTAINER_NAME:$CERT_SOURCE_DIR/fullchain.pem" "$cert_dest_dir/fullchain.pem"
    
    # Set appropriate permissions
    chmod 644 "$cert_dest_dir/cert.pem" "$cert_dest_dir/fullchain.pem"
    chmod 640 "$cert_dest_dir/privkey.pem"
    
    log "✓ Certificates copied to $project_name ($cert_dest_dir)"
    
    # Verify copied files
    local copied_files=("cert.pem" "privkey.pem" "fullchain.pem")
    for file in "${copied_files[@]}"; do
        if [ ! -f "$cert_dest_dir/$file" ]; then
            error "Failed to copy certificate file: $file"
            return 1
        fi
    done
    
    info "Certificate files verified in $project_name project"
}

# Main execution
main() {
    log "=== Certificate Distribution Started ==="
    
    check_certbot_container
    verify_certificates
    
    # Copy to LDAP project
    if [ -d "$LDAP_PROJECT_PATH" ]; then
        copy_certs_to_project "LDAP" "$LDAP_PROJECT_PATH" "$LDAP_PROJECT_PATH/docker/openldap/certs"
    else
        warn "LDAP project not found at $LDAP_PROJECT_PATH, skipping"
    fi
    
    # Copy to FreeRADIUS project  
    if [ -d "$FREERADIUS_PROJECT_PATH" ]; then
        copy_certs_to_project "FreeRADIUS" "$FREERADIUS_PROJECT_PATH" "$FREERADIUS_PROJECT_PATH/docker/freeradius/certs"
    else
        warn "FreeRADIUS project not found at $FREERADIUS_PROJECT_PATH, skipping"
    fi
    
    log "=== Certificate Distribution Completed ==="
    
    # Show certificate expiration info
    log "Certificate expiration information:"
    docker exec "$CERTBOT_CONTAINER_NAME" openssl x509 -in "$CERT_SOURCE_DIR/cert.pem" -noout -dates
}

# Run main function
main "$@"