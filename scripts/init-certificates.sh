#!/bin/bash
# Script: init-certificates.sh
# Purpose: Initial Let's Encrypt certificate acquisition for LDAP server
# Usage: ./init-certificates.sh

set -euo pipefail
IFS=$'\n\t'

# Trap errors
trap 'echo "Error on line $LINENO"' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Validate prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v docker >/dev/null 2>&1 || { 
        error "Docker is required but not installed"
        exit 1
    }
    
    command -v docker compose >/dev/null 2>&1 || { 
        error "Docker Compose is required but not installed"
        exit 1
    }
    
    if [ ! -f ".env" ]; then
        error ".env file not found. Copy .env.example to .env and configure it first"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Load environment variables
load_environment() {
    log "Loading environment variables..."
    
    # Source the .env file
    set -a  # Automatically export all variables
    # shellcheck source=../.env
    source .env
    set +a
    
    # Validate required variables
    local required_vars=("LDAP_DOMAIN" "LETSENCRYPT_EMAIL")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error "Required environment variable $var not set in .env file"
            exit 1
        fi
    done
    
    log "Environment loaded: Domain=$LDAP_DOMAIN, Email=$LETSENCRYPT_EMAIL"
}

# Check if domain resolves to current IP
check_domain_dns() {
    log "Checking DNS resolution for $LDAP_DOMAIN..."
    
    # Get external IP of this server
    local server_ip
    server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "unknown")
    
    if [ "$server_ip" = "unknown" ]; then
        warn "Could not determine server IP. Skipping DNS check"
        return 0
    fi
    
    # Resolve domain
    local domain_ip
    domain_ip=$(dig +short "$LDAP_DOMAIN" | tail -n1)
    
    if [ "$domain_ip" != "$server_ip" ]; then
        warn "Domain $LDAP_DOMAIN resolves to $domain_ip but server IP is $server_ip"
        warn "Certificate acquisition may fail if DNS is not properly configured"
        
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log "DNS check passed: $LDAP_DOMAIN resolves to $server_ip"
    fi
}

# Stop any running services
stop_services() {
    log "Stopping any running services..."
    
    if docker compose ps | grep -q "Up"; then
        docker compose down
    fi
    
    # Stop any process using port 80
    local port80_pid
    port80_pid=$(lsof -ti:80 || echo "")
    if [ -n "$port80_pid" ]; then
        warn "Stopping process using port 80 (PID: $port80_pid)"
        sudo kill "$port80_pid" || true
        sleep 2
    fi
}

# Acquire certificate using certbot standalone
acquire_certificate() {
    log "Acquiring Let's Encrypt certificate for $LDAP_DOMAIN..."
    
    # Create certificates directory
    mkdir -p volumes/certificates
    
    # Use staging server for testing
    local staging_flag=""
    if [ "${ENVIRONMENT:-development}" != "production" ]; then
        staging_flag="--staging"
        warn "Using Let's Encrypt staging server (test certificates)"
    fi
    
    # Run certbot in standalone mode
    docker run --rm \
        -p 80:80 \
        -v "$(pwd)/volumes/certificates:/etc/letsencrypt" \
        certbot/certbot:v2.7.4 \
        certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "$LETSENCRYPT_EMAIL" \
        --domains "$LDAP_DOMAIN" \
        --rsa-key-size 4096 \
        $staging_flag
    
    log "Certificate acquisition completed"
}

# Verify certificate files
verify_certificate() {
    log "Verifying certificate files..."
    
    local cert_dir="volumes/certificates/live/$LDAP_DOMAIN"
    
    if [ ! -d "$cert_dir" ]; then
        error "Certificate directory not found: $cert_dir"
        exit 1
    fi
    
    local required_files=("cert.pem" "privkey.pem" "fullchain.pem")
    for file in "${required_files[@]}"; do
        if [ ! -f "$cert_dir/$file" ]; then
            error "Required certificate file not found: $cert_dir/$file"
            exit 1
        fi
    done
    
    # Check certificate validity
    local cert_info
    cert_info=$(openssl x509 -in "$cert_dir/cert.pem" -text -noout)
    
    if echo "$cert_info" | grep -q "$LDAP_DOMAIN"; then
        log "Certificate verification passed"
        
        # Show certificate details
        local expiry_date
        expiry_date=$(openssl x509 -in "$cert_dir/cert.pem" -noout -enddate | cut -d= -f2)
        log "Certificate expires: $expiry_date"
    else
        error "Certificate verification failed - domain mismatch"
        exit 1
    fi
}

# Set proper permissions
set_permissions() {
    log "Setting certificate permissions..."
    
    # Ensure proper ownership and permissions
    sudo chown -R "$USER:$USER" volumes/certificates
    chmod -R 755 volumes/certificates
    
    # Protect private keys
    find volumes/certificates -name "privkey.pem" -exec chmod 600 {} \;
    
    log "Permissions set correctly"
}

# Main function
main() {
    log "Starting certificate initialization..."
    
    check_prerequisites
    load_environment
    check_domain_dns
    stop_services
    acquire_certificate
    verify_certificate
    set_permissions
    
    log "Certificate initialization completed successfully!"
    log "You can now start the LDAP services with: make deploy"
}

# Run main function
main "$@"