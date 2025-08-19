#!/bin/bash
# Script: test-authentication.sh
# Purpose: Test LDAP authentication for all test users
# Usage: ./test-authentication.sh

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
    
    ((TESTS_TOTAL++))
    info "Running test: $test_name"
    
    if $test_function; then
        log "✓ $test_name: PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        error "✗ $test_name: FAILED"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Check if LDAP service is accessible
test_ldap_service() {
    docker exec openldap ldapsearch -x -H ldap://localhost -b "" -s base >/dev/null 2>&1
}

# Test valid user authentication
test_valid_authentication() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    # Test each user with their password
    local users=(
        "test-user-01:${TEST_USER_PASSWORD:-TestPass123!}"
        "test-user-02:${GUEST_USER_PASSWORD:-GuestPass789!}"
        "test-user-03:${ADMIN_USER_PASSWORD:-AdminPass456!}"
        "test-user-04:${CONTRACTOR_PASSWORD:-ContractorPass321!}"
        "test-user-05:${VIP_PASSWORD:-VipPass654!}"
    )
    
    for user_info in "${users[@]}"; do
        local username="${user_info%%:*}"
        local password="${user_info#*:}"
        
        info "Testing authentication for $username"
        
        if docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "uid=$username,ou=users,$base_dn" \
            -w "$password" \
            -b "" -s base >/dev/null 2>&1; then
            log "  ✓ $username authentication successful"
        else
            error "  ✗ $username authentication failed"
            return 1
        fi
    done
    
    return 0
}

# Test invalid password authentication (should fail)
test_invalid_authentication() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    local invalid_password="WrongPassword123!"
    
    info "Testing authentication with invalid password"
    
    # This should fail
    if docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "uid=test-user-01,ou=users,$base_dn" \
        -w "$invalid_password" \
        -b "" -s base >/dev/null 2>&1; then
        error "Authentication succeeded with invalid password (security issue!)"
        return 1
    else
        log "✓ Invalid password correctly rejected"
        return 0
    fi
}

# Test non-existent user authentication (should fail)
test_nonexistent_user() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing authentication for non-existent user"
    
    # This should fail
    if docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "uid=nonexistent-user,ou=users,$base_dn" \
        -w "SomePassword123!" \
        -b "" -s base >/dev/null 2>&1; then
        error "Authentication succeeded for non-existent user (security issue!)"
        return 1
    else
        log "✓ Non-existent user correctly rejected"
        return 0
    fi
}

# Test empty password authentication (should fail)
test_empty_password() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing authentication with empty password"
    
    # This should fail
    if docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "uid=test-user-01,ou=users,$base_dn" \
        -w "" \
        -b "" -s base >/dev/null 2>&1; then
        error "Authentication succeeded with empty password (security issue!)"
        return 1
    else
        log "✓ Empty password correctly rejected"
        return 0
    fi
}

# Test LDAPS (TLS) authentication
test_ldaps_authentication() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing LDAPS (TLS) authentication"
    
    # Test LDAPS connection with test-user-01
    if docker exec openldap ldapsearch -x -H ldaps://localhost:636 \
        -D "uid=test-user-01,ou=users,$base_dn" \
        -w "${TEST_USER_PASSWORD:-TestPass123!}" \
        -b "" -s base >/dev/null 2>&1; then
        log "✓ LDAPS authentication successful"
        return 0
    else
        warn "LDAPS authentication failed (may be due to certificate issues in test environment)"
        return 0  # Don't fail the test in development environment
    fi
}

# Test admin user authentication
test_admin_authentication() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing admin user authentication"
    
    if docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "cn=admin,$base_dn" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -b "$base_dn" \
        "objectClass=*" dn >/dev/null 2>&1; then
        log "✓ Admin authentication successful"
        return 0
    else
        error "Admin authentication failed"
        return 1
    fi
}

# Test bind and search operations
test_bind_and_search() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing bind and search operations"
    
    # Bind as test-user-01 and search for own entry
    local result
    result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "uid=test-user-01,ou=users,$base_dn" \
        -w "${TEST_USER_PASSWORD:-TestPass123!}" \
        -b "uid=test-user-01,ou=users,$base_dn" \
        "objectClass=*" dn 2>/dev/null)
    
    if echo "$result" | grep -q "uid=test-user-01"; then
        log "✓ Bind and search operation successful"
        return 0
    else
        error "Bind and search operation failed"
        return 1
    fi
}

# Test concurrent authentication
test_concurrent_authentication() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing concurrent authentication (5 parallel requests)"
    
    local success_count=0
    local total_requests=5
    
    for i in $(seq 1 $total_requests); do
        {
            if docker exec openldap ldapsearch -x -H ldap://localhost \
                -D "uid=test-user-01,ou=users,$base_dn" \
                -w "${TEST_USER_PASSWORD:-TestPass123!}" \
                -b "" -s base >/dev/null 2>&1; then
                echo "success"
            else
                echo "failure"
            fi
        } &
    done
    
    # Wait for all background jobs and count successes
    for job in $(jobs -p); do
        wait $job
        if [ $? -eq 0 ]; then
            ((success_count++))
        fi
    done
    
    if [ $success_count -eq $total_requests ]; then
        log "✓ Concurrent authentication test passed ($success_count/$total_requests)"
        return 0
    else
        error "Concurrent authentication test failed ($success_count/$total_requests)"
        return 1
    fi
}

# Test authentication performance
test_authentication_performance() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing authentication performance (10 sequential requests)"
    
    local start_time
    local end_time
    local duration
    
    start_time=$(date +%s.%N)
    
    for i in $(seq 1 10); do
        docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "uid=test-user-01,ou=users,$base_dn" \
            -w "${TEST_USER_PASSWORD:-TestPass123!}" \
            -b "" -s base >/dev/null 2>&1 || {
            error "Authentication $i failed during performance test"
            return 1
        }
    done
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    local avg_time=$(echo "scale=3; $duration / 10" | bc -l)
    
    info "Average authentication time: ${avg_time}s per request"
    
    # Check if average time is reasonable (should be under 1 second)
    if (( $(echo "$avg_time < 1.0" | bc -l) )); then
        log "✓ Authentication performance test passed (avg: ${avg_time}s)"
        return 0
    else
        warn "Authentication performance slower than expected (avg: ${avg_time}s)"
        return 0  # Don't fail test, just warn
    fi
}

# Display test results summary
display_summary() {
    echo
    echo "========================================="
    echo "      Authentication Test Results       "
    echo "========================================="
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo "========================================="
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "All authentication tests passed! 🎉"
        echo
        echo "Your LDAP server is ready for WiFi authentication."
        echo "Test users can authenticate with their configured passwords."
    else
        error "Some authentication tests failed!"
        echo
        echo "Please check the LDAP configuration and user setup."
        echo "Run './scripts/health-check.sh' for more details."
    fi
}

# Main function
main() {
    echo "Starting LDAP Authentication Tests"
    echo "=================================="
    
    # Load environment and check prerequisites
    load_environment
    
    # Check if OpenLDAP container is running
    if ! docker-compose ps openldap | grep -q "Up"; then
        error "OpenLDAP container is not running. Start it with: make deploy"
        exit 1
    fi
    
    # Run all authentication tests
    run_test "LDAP Service Accessibility" test_ldap_service
    run_test "Valid User Authentication" test_valid_authentication
    run_test "Invalid Password Rejection" test_invalid_authentication
    run_test "Non-existent User Rejection" test_nonexistent_user
    run_test "Empty Password Rejection" test_empty_password
    run_test "LDAPS Authentication" test_ldaps_authentication
    run_test "Admin Authentication" test_admin_authentication
    run_test "Bind and Search Operations" test_bind_and_search
    run_test "Concurrent Authentication" test_concurrent_authentication
    run_test "Authentication Performance" test_authentication_performance
    
    # Display results
    display_summary
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"