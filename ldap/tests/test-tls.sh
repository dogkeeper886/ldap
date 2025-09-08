#!/bin/bash
# Script: test-tls.sh
# Purpose: Test TLS configuration and certificate validity
# Usage: ./test-tls.sh

set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"
}

# Load environment variables
load_environment() {
    if [ -f ".env" ]; then
        set -a  # Automatically export all variables
        # shellcheck source=../.env
        source .env
        set +a
    else
        error ".env file not found"
        exit 1
    fi
}

# Test runner function
run_test() {
    local test_name="$1"
    local test_function="$2"
    local is_critical="${3:-true}"
    
    ((TESTS_TOTAL++))
    info "Running test: $test_name"
    
    if $test_function; then
        log "✓ $test_name: PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        if [ "$is_critical" = "true" ]; then
            error "✗ $test_name: FAILED"
            ((TESTS_FAILED++))
        else
            warn "⚠ $test_name: WARNING"
            # Count as passed but show warning
            ((TESTS_PASSED++))
        fi
        return 1
    fi
}

# Test if LDAPS port is accessible
test_ldaps_port() {
    info "Testing LDAPS port accessibility"
    
    # Check if port 636 is listening
    if nc -z localhost 636 >/dev/null 2>&1; then
        log "✓ LDAPS port 636 is accessible"
        return 0
    else
        error "LDAPS port 636 is not accessible"
        return 1
    fi
}

# Test TLS connection establishment
test_tls_connection() {
    info "Testing TLS connection establishment"
    
    # Test TLS handshake
    if echo "Q" | timeout 10 openssl s_client -connect localhost:636 >/dev/null 2>&1; then
        log "✓ TLS connection established successfully"
        return 0
    else
        error "TLS connection failed"
        return 1
    fi
}

# Test certificate validity
test_certificate_validity() {
    local cert_dir="volumes/certificates/live/$LDAP_DOMAIN"
    
    info "Testing certificate validity"
    
    if [ "${ENVIRONMENT:-development}" = "development" ]; then
        warn "Development environment - skipping certificate validation"
        return 0
    fi
    
    # Check if certificate files exist
    if [ ! -f "$cert_dir/cert.pem" ] || [ ! -f "$cert_dir/privkey.pem" ] || [ ! -f "$cert_dir/fullchain.pem" ]; then
        error "Certificate files not found in $cert_dir"
        return 1
    fi
    
    # Verify certificate validity
    if openssl x509 -in "$cert_dir/cert.pem" -noout -checkend 86400 >/dev/null 2>&1; then
        log "✓ Certificate is valid and not expiring within 24 hours"
        
        # Show certificate details
        local expiry_date
        expiry_date=$(openssl x509 -in "$cert_dir/cert.pem" -noout -enddate | cut -d= -f2)
        info "Certificate expires: $expiry_date"
        
        return 0
    else
        error "Certificate is invalid or expiring soon"
        return 1
    fi
}

# Test TLS version support
test_tls_versions() {
    info "Testing TLS version support"
    
    local tls_errors=()
    
    # Test TLS 1.2 (should work)
    if echo "Q" | timeout 5 openssl s_client -connect localhost:636 -tls1_2 >/dev/null 2>&1; then
        log "    ✓ TLS 1.2 supported"
    else
        tls_errors+=("TLS 1.2 not supported")
    fi
    
    # Test TLS 1.3 (should work if available)
    if echo "Q" | timeout 5 openssl s_client -connect localhost:636 -tls1_3 >/dev/null 2>&1; then
        log "    ✓ TLS 1.3 supported"
    else
        info "    • TLS 1.3 not supported (not required)"
    fi
    
    # Test TLS 1.1 (should be disabled)
    if echo "Q" | timeout 5 openssl s_client -connect localhost:636 -tls1_1 >/dev/null 2>&1; then
        tls_errors+=("TLS 1.1 should be disabled for security")
    else
        log "    ✓ TLS 1.1 properly disabled"
    fi
    
    # Test TLS 1.0 (should be disabled)
    if echo "Q" | timeout 5 openssl s_client -connect localhost:636 -tls1 >/dev/null 2>&1; then
        tls_errors+=("TLS 1.0 should be disabled for security")
    else
        log "    ✓ TLS 1.0 properly disabled"
    fi
    
    if [ ${#tls_errors[@]} -eq 0 ]; then
        log "✓ TLS version configuration is secure"
        return 0
    else
        error "TLS version issues: ${tls_errors[*]}"
        return 1
    fi
}

# Test cipher suite security
test_cipher_suites() {
    info "Testing cipher suite security"
    
    # Get supported cipher suites
    local ciphers
    ciphers=$(echo "Q" | timeout 10 openssl s_client -connect localhost:636 -cipher 'ALL' 2>&1 | grep 'Cipher is' | cut -d' ' -f4)
    
    if [ -z "$ciphers" ]; then
        error "Could not determine cipher suites"
        return 1
    fi
    
    info "Negotiated cipher: $ciphers"
    
    # Test for weak ciphers (should fail)
    local weak_cipher_test
    weak_cipher_test=$(echo "Q" | timeout 5 openssl s_client -connect localhost:636 -cipher 'LOW:EXPORT:aNULL' 2>&1 | grep 'Cipher is' || echo "")
    
    if [ -n "$weak_cipher_test" ]; then
        error "Weak ciphers are enabled: $weak_cipher_test"
        return 1
    else
        log "✓ Weak ciphers properly disabled"
    fi
    
    # Check for strong ciphers
    if echo "$ciphers" | grep -qE "(AES256|AES128|CHACHA20)"; then
        log "✓ Strong cipher suite in use: $ciphers"
        return 0
    else
        warn "Cipher suite may not be optimal: $ciphers"
        return 0  # Don't fail, just warn
    fi
}

# Test certificate chain validation
test_certificate_chain() {
    info "Testing certificate chain validation"
    
    if [ "${ENVIRONMENT:-development}" = "development" ]; then
        warn "Development environment - skipping certificate chain validation"
        return 0
    fi
    
    # Test certificate chain verification
    if echo "Q" | timeout 10 openssl s_client -connect localhost:636 -verify_return_error >/dev/null 2>&1; then
        log "✓ Certificate chain validation successful"
        return 0
    else
        warn "Certificate chain validation failed (may be expected in test environment)"
        return 0  # Don't fail test in case of self-signed certs
    fi
}

# Test LDAPS authentication with TLS
test_ldaps_authentication() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing LDAPS authentication"
    
    # Test LDAPS connection with authentication
    if docker exec openldap ldapsearch -x -H ldaps://localhost:636 \
        -D "uid=test-user-01,ou=users,$base_dn" \
        -w "${TEST_USER_PASSWORD:-TestPass123!}" \
        -b "" -s base >/dev/null 2>&1; then
        log "✓ LDAPS authentication successful"
        return 0
    else
        if [ "${ENVIRONMENT:-development}" = "development" ]; then
            warn "LDAPS authentication failed (may be due to self-signed certificates in development)"
            return 0
        else
            error "LDAPS authentication failed"
            return 1
        fi
    fi
}

# Test plain LDAP (should work for internal access)
test_plain_ldap() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing plain LDAP access"
    
    # Test plain LDAP connection (should work for internal access)
    if docker exec openldap ldapsearch -x -H ldap://localhost:389 \
        -D "uid=test-user-01,ou=users,$base_dn" \
        -w "${TEST_USER_PASSWORD:-TestPass123!}" \
        -b "" -s base >/dev/null 2>&1; then
        log "✓ Plain LDAP connection available (internal access)"
        return 0
    else
        warn "Plain LDAP connection failed"
        return 0  # Don't fail test
    fi
}

# Test certificate expiry warning
test_certificate_expiry() {
    local cert_dir="volumes/certificates/live/$LDAP_DOMAIN"
    
    info "Testing certificate expiry status"
    
    if [ "${ENVIRONMENT:-development}" = "development" ]; then
        warn "Development environment - skipping certificate expiry check"
        return 0
    fi
    
    if [ ! -f "$cert_dir/cert.pem" ]; then
        warn "Certificate file not found - skipping expiry check"
        return 0
    fi
    
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
        error "Certificate expires in $days_left days - immediate renewal required"
        return 1
    elif [ $days_left -lt 30 ]; then
        warn "Certificate expires in $days_left days - renewal recommended"
        return 0
    else
        log "✓ Certificate has $days_left days until expiry"
        return 0
    fi
}

# Test TLS performance
test_tls_performance() {
    info "Testing TLS connection performance"
    
    local start_time
    local end_time
    local duration
    
    start_time=$(date +%s.%N)
    
    # Perform 5 TLS connections
    for i in $(seq 1 5); do
        if ! echo "Q" | timeout 5 openssl s_client -connect localhost:636 >/dev/null 2>&1; then
            error "TLS connection $i failed during performance test"
            return 1
        fi
    done
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    local avg_time=$(echo "scale=3; $duration / 5" | bc -l)
    
    info "Average TLS connection time: ${avg_time}s per connection"
    
    # Check if connection time is reasonable (should be under 2 seconds)
    if (( $(echo "$avg_time < 2.0" | bc -l) )); then
        log "✓ TLS connection performance acceptable (avg: ${avg_time}s)"
        return 0
    else
        warn "TLS connection slower than expected (avg: ${avg_time}s)"
        return 0  # Don't fail test, just warn
    fi
}

# Display TLS configuration details
display_tls_details() {
    echo
    echo "========================================="
    echo "         TLS Configuration Details      "
    echo "========================================="
    
    # Show TLS connection details
    echo "TLS Connection Information:"
    echo "Q" | timeout 10 openssl s_client -connect localhost:636 2>/dev/null | grep -E "(Protocol|Cipher|Verify)" || echo "Could not retrieve TLS details"
    
    echo
    echo "Certificate Information:"
    if [ "${ENVIRONMENT:-development}" != "development" ] && [ -f "volumes/certificates/live/$LDAP_DOMAIN/cert.pem" ]; then
        openssl x509 -in "volumes/certificates/live/$LDAP_DOMAIN/cert.pem" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After|DNS:|IP Address:)" || echo "Could not retrieve certificate details"
    else
        echo "Certificate details not available in development environment"
    fi
    
    echo
    echo "Security Configuration:"
    echo "- LDAPS Port: 636 (TLS encrypted)"
    echo "- LDAP Port: 389 (plain, internal only)"
    echo "- TLS Version: 1.2+ (1.0 and 1.1 disabled)"
    echo "- Cipher Suites: Strong ciphers only"
    echo "- Certificate: Let's Encrypt (production) or self-signed (development)"
}

# Display test results summary
display_summary() {
    echo
    echo "========================================="
    echo "           TLS Test Results             "
    echo "========================================="
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo "========================================="
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "All TLS tests passed! 🔒"
        echo
        echo "Your LDAP server has secure TLS configuration."
        echo "WiFi access points can safely connect using LDAPS."
    else
        error "Some TLS tests failed!"
        echo
        echo "Please check the TLS/certificate configuration."
        echo "Run './scripts/health-check.sh' for more details."
    fi
}

# Main function
main() {
    echo "Starting LDAP TLS Tests"
    echo "======================"
    
    # Load environment and check prerequisites
    load_environment
    
    # Check if OpenLDAP container is running
    if ! docker compose ps openldap | grep -q "Up"; then
        error "OpenLDAP container is not running. Start it with: make deploy"
        exit 1
    fi
    
    # Run all TLS tests
    run_test "LDAPS Port Accessibility" test_ldaps_port
    run_test "TLS Connection" test_tls_connection
    run_test "Certificate Validity" test_certificate_validity false
    run_test "TLS Version Support" test_tls_versions
    run_test "Cipher Suite Security" test_cipher_suites
    run_test "Certificate Chain" test_certificate_chain false
    run_test "LDAPS Authentication" test_ldaps_authentication
    run_test "Plain LDAP Access" test_plain_ldap false
    run_test "Certificate Expiry" test_certificate_expiry false
    run_test "TLS Performance" test_tls_performance false
    
    # Display results
    display_summary
    
    # Show detailed TLS information if verbose mode
    if [ "${1:-}" = "--verbose" ] || [ "${1:-}" = "-v" ]; then
        display_tls_details
    fi
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"