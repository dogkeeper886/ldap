#!/bin/bash
# Script: health-check.sh
# Purpose: Comprehensive health check for LDAP server and certificate status
# Usage: ./health-check.sh

set -euo pipefail
IFS=$'\n\t'

# Trap errors
trap 'echo "Error on line $LINENO"' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Global variables
HEALTH_STATUS=0
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Load environment variables
load_environment() {
    if [ -f ".env" ]; then
        set -a  # Automatically export all variables
        # shellcheck source=../.env
        source .env
        set +a
    else
        warn ".env file not found, using defaults"
        LDAP_DOMAIN=${LDAP_DOMAIN:-"example.com"}
    fi
}

# Helper function to run checks
run_check() {
    local check_name="$1"
    local check_function="$2"
    local is_critical="${3:-true}"
    
    info "Running check: $check_name"
    
    if $check_function; then
        log "✓ $check_name: PASSED"
        ((CHECKS_PASSED++))
    else
        if [ "$is_critical" = "true" ]; then
            error "✗ $check_name: FAILED"
            ((CHECKS_FAILED++))
            HEALTH_STATUS=1
        else
            warn "⚠ $check_name: WARNING"
            ((CHECKS_WARNING++))
        fi
    fi
}

# Check Docker and Docker Compose
check_docker() {
    command -v docker >/dev/null 2>&1 && \
    command -v docker compose >/dev/null 2>&1 && \
    docker info >/dev/null 2>&1
}

# Check container status
check_containers() {
    docker compose ps | grep -q "openldap.*Up" && \
    docker compose ps | grep -q "certbot.*Up"
}

# Check LDAP service on plain port
check_ldap_plain() {
    docker exec openldap ldapsearch -x -H ldap://localhost:389 -b "" -s base >/dev/null 2>&1
}

# Check LDAPS service on TLS port
check_ldaps_tls() {
    if [ "${ENVIRONMENT:-development}" = "development" ]; then
        # In development, skip TLS verification
        docker exec openldap ldapsearch -x -H ldaps://localhost:636 -b "" -s base >/dev/null 2>&1
    else
        # In production, verify TLS
        echo "Q" | openssl s_client -connect localhost:636 -verify_return_error >/dev/null 2>&1
    fi
}

# Check certificate validity
check_certificate() {
    local cert_dir="volumes/certificates/live/$LDAP_DOMAIN"
    
    # Check if certificate files exist
    [ -f "$cert_dir/cert.pem" ] && \
    [ -f "$cert_dir/privkey.pem" ] && \
    [ -f "$cert_dir/fullchain.pem" ] || return 1
    
    # Check certificate expiry
    local expiry_date
    expiry_date=$(openssl x509 -in "$cert_dir/cert.pem" -noout -enddate | cut -d= -f2)
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch
    current_epoch=$(date +%s)
    local days_left
    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ $days_left -lt 7 ]; then
        warn "Certificate expires in $days_left days - renewal recommended"
        return 1
    elif [ $days_left -lt 30 ]; then
        info "Certificate expires in $days_left days"
    fi
    
    return 0
}

# Check if test users exist
check_test_users() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    local users=("test-user-01" "test-user-02" "test-user-03" "test-user-04" "test-user-05")
    local user_count=0
    
    for user in "${users[@]}"; do
        if docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -b "ou=users,$base_dn" \
            "uid=$user" dn 2>/dev/null | grep -q "dn: uid=$user"; then
            ((user_count++))
        fi
    done
    
    [ $user_count -eq 5 ]
}

# Check test user authentication
check_authentication() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    # Test authentication with test-user-01
    docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "uid=test-user-01,ou=users,$base_dn" \
        -w "${TEST_USER_PASSWORD:-TestPass123!}" \
        -b "" -s base >/dev/null 2>&1
}

# Check RUCKUS required attributes
check_ruckus_attributes() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    # Check if test-user-01 has all required RUCKUS attributes
    local result
    result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "cn=admin,$base_dn" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -b "uid=test-user-01,ou=users,$base_dn" \
        displayName mail telephoneNumber department 2>/dev/null)
    
    echo "$result" | grep -q "displayName:" && \
    echo "$result" | grep -q "mail:" && \
    echo "$result" | grep -q "telephoneNumber:" && \
    echo "$result" | grep -q "department:"
}

# Check disk space
check_disk_space() {
    local disk_usage
    disk_usage=$(df /var/lib/docker 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
    
    if [ "$disk_usage" -gt 90 ]; then
        error "Critical: Disk usage at ${disk_usage}%"
        return 1
    elif [ "$disk_usage" -gt 80 ]; then
        warn "Warning: Disk usage at ${disk_usage}%"
        return 1
    fi
    
    info "Disk usage: ${disk_usage}%"
    return 0
}

# Check memory usage
check_memory() {
    local container_stats
    container_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep openldap || echo "openldap N/A")
    
    info "OpenLDAP memory usage: $(echo "$container_stats" | awk '{print $2}')"
    return 0
}

# Check network connectivity
check_network() {
    # Check if ports are accessible
    nc -z localhost 636 >/dev/null 2>&1 && \
    nc -z localhost 389 >/dev/null 2>&1
}

# Check log errors
check_logs() {
    local error_count
    error_count=$(docker compose logs --tail=100 openldap 2>/dev/null | grep -c "ERROR\|FATAL" || echo "0")
    
    if [ "$error_count" -gt 0 ]; then
        warn "Found $error_count error(s) in recent logs"
        return 1
    fi
    
    return 0
}

# Generate detailed report
generate_report() {
    echo
    echo "========================================="
    echo "         LDAP Health Check Report        "
    echo "========================================="
    echo "Timestamp: $(date)"
    echo "Domain: $LDAP_DOMAIN"
    echo "Environment: ${ENVIRONMENT:-development}"
    echo
    echo "Summary:"
    echo "✓ Checks Passed: $CHECKS_PASSED"
    echo "⚠ Warnings: $CHECKS_WARNING"
    echo "✗ Checks Failed: $CHECKS_FAILED"
    echo
    
    if [ $HEALTH_STATUS -eq 0 ]; then
        log "Overall Status: HEALTHY"
    else
        error "Overall Status: UNHEALTHY"
    fi
    
    echo "========================================="
}

# Display container information
show_container_info() {
    echo
    info "Container Status:"
    docker compose ps
    
    echo
    info "Recent Log Entries:"
    docker compose logs --tail=5 openldap 2>/dev/null || warn "Could not retrieve logs"
}

# Main function
main() {
    log "Starting comprehensive health check..."
    
    load_environment
    
    # Run all health checks
    run_check "Docker Services" check_docker
    run_check "Container Status" check_containers
    run_check "LDAP Plain Connection" check_ldap_plain
    run_check "LDAPS TLS Connection" check_ldaps_tls
    run_check "Certificate Validity" check_certificate false
    run_check "Test Users Exist" check_test_users
    run_check "User Authentication" check_authentication
    run_check "RUCKUS Attributes" check_ruckus_attributes
    run_check "Disk Space" check_disk_space false
    run_check "Memory Usage" check_memory false
    run_check "Network Connectivity" check_network
    run_check "Log Errors" check_logs false
    
    generate_report
    
    if [ "${1:-}" = "--verbose" ] || [ "${1:-}" = "-v" ]; then
        show_container_info
    fi
    
    exit $HEALTH_STATUS
}

# Run main function
main "$@"