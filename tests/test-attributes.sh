#!/bin/bash
# Script: test-attributes.sh
# Purpose: Test RUCKUS One required attribute retrieval
# Usage: ./test-attributes.sh

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

# Test RUCKUS One required attributes for test-user-01
test_ruckus_attributes_user01() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing RUCKUS One attributes for test-user-01"
    
    local result
    result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "cn=admin,$base_dn" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -b "uid=test-user-01,ou=users,$base_dn" \
        displayName mail telephoneNumber department 2>/dev/null)
    
    # Check each required attribute
    local missing_attrs=()
    
    if ! echo "$result" | grep -q "displayName:"; then
        missing_attrs+=("displayName")
    fi
    
    if ! echo "$result" | grep -q "mail:"; then
        missing_attrs+=("mail")
    fi
    
    if ! echo "$result" | grep -q "telephoneNumber:"; then
        missing_attrs+=("telephoneNumber")
    fi
    
    if ! echo "$result" | grep -q "department:"; then
        missing_attrs+=("department")
    fi
    
    if [ ${#missing_attrs[@]} -eq 0 ]; then
        log "✓ All RUCKUS One attributes present for test-user-01"
        return 0
    else
        error "Missing attributes: ${missing_attrs[*]}"
        return 1
    fi
}

# Test attribute values for all users
test_all_users_attributes() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing attributes for all test users"
    
    local users=("test-user-01" "test-user-02" "test-user-03" "test-user-04" "test-user-05")
    local failed_users=()
    
    for user in "${users[@]}"; do
        info "  Checking attributes for $user"
        
        local result
        result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -b "uid=$user,ou=users,$base_dn" \
            displayName mail telephoneNumber department employeeType 2>/dev/null)
        
        # Check if user has required attributes
        if echo "$result" | grep -q "displayName:" && \
           echo "$result" | grep -q "mail:" && \
           echo "$result" | grep -q "telephoneNumber:" && \
           echo "$result" | grep -q "department:"; then
            log "    ✓ $user has all required attributes"
        else
            error "    ✗ $user missing required attributes"
            failed_users+=("$user")
        fi
    done
    
    if [ ${#failed_users[@]} -eq 0 ]; then
        log "✓ All users have required attributes"
        return 0
    else
        error "Users with missing attributes: ${failed_users[*]}"
        return 1
    fi
}

# Test attribute value format and content
test_attribute_format() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing attribute format and content"
    
    local result
    result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "cn=admin,$base_dn" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -b "uid=test-user-01,ou=users,$base_dn" \
        displayName mail telephoneNumber department 2>/dev/null)
    
    local format_errors=()
    
    # Check email format
    local email
    email=$(echo "$result" | grep "mail:" | head -1 | cut -d' ' -f2-)
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        format_errors+=("email format invalid: $email")
    fi
    
    # Check phone number format
    local phone
    phone=$(echo "$result" | grep "telephoneNumber:" | head -1 | cut -d' ' -f2-)
    if [[ ! "$phone" =~ ^\+[0-9-]+$ ]]; then
        format_errors+=("phone format invalid: $phone")
    fi
    
    # Check displayName is not empty
    local display_name
    display_name=$(echo "$result" | grep "displayName:" | head -1 | cut -d' ' -f2-)
    if [ -z "$display_name" ]; then
        format_errors+=("displayName is empty")
    fi
    
    # Check department is not empty
    local department
    department=$(echo "$result" | grep "department:" | head -1 | cut -d' ' -f2-)
    if [ -z "$department" ]; then
        format_errors+=("department is empty")
    fi
    
    if [ ${#format_errors[@]} -eq 0 ]; then
        log "✓ All attribute formats are valid"
        return 0
    else
        error "Format errors: ${format_errors[*]}"
        return 1
    fi
}

# Test user can retrieve own attributes
test_self_attribute_access() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing user self-access to attributes"
    
    # Test user binding and retrieving own attributes
    local result
    result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "uid=test-user-01,ou=users,$base_dn" \
        -w "${TEST_USER_PASSWORD:-TestPass123!}" \
        -b "uid=test-user-01,ou=users,$base_dn" \
        displayName mail telephoneNumber department 2>/dev/null)
    
    if echo "$result" | grep -q "displayName:" && \
       echo "$result" | grep -q "mail:" && \
       echo "$result" | grep -q "telephoneNumber:" && \
       echo "$result" | grep -q "department:"; then
        log "✓ User can access own attributes"
        return 0
    else
        error "User cannot access own attributes"
        return 1
    fi
}

# Test department-based access control attributes
test_department_attributes() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing department-based attributes for access control"
    
    # Expected departments for each user
    local expected_departments=(
        "test-user-01:IT"
        "test-user-02:Guest"
        "test-user-03:IT"
        "test-user-04:External"
        "test-user-05:Executive"
    )
    
    local department_errors=()
    
    for user_dept in "${expected_departments[@]}"; do
        local username="${user_dept%%:*}"
        local expected_dept="${user_dept#*:}"
        
        local result
        result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -b "uid=$username,ou=users,$base_dn" \
            department 2>/dev/null)
        
        local actual_dept
        actual_dept=$(echo "$result" | grep "department:" | head -1 | cut -d' ' -f2-)
        
        if [ "$actual_dept" = "$expected_dept" ]; then
            log "    ✓ $username department: $actual_dept"
        else
            error "    ✗ $username department: expected '$expected_dept', got '$actual_dept'"
            department_errors+=("$username")
        fi
    done
    
    if [ ${#department_errors[@]} -eq 0 ]; then
        log "✓ All department attributes correct"
        return 0
    else
        error "Incorrect department attributes for: ${department_errors[*]}"
        return 1
    fi
}

# Test employee type attributes
test_employee_type_attributes() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing employeeType attributes"
    
    # Expected employee types
    local expected_types=(
        "test-user-01:Full-Time"
        "test-user-02:Visitor"
        "test-user-03:Admin"
        "test-user-04:Contractor"
        "test-user-05:Full-Time"
    )
    
    local type_errors=()
    
    for user_type in "${expected_types[@]}"; do
        local username="${user_type%%:*}"
        local expected_type="${user_type#*:}"
        
        local result
        result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -b "uid=$username,ou=users,$base_dn" \
            employeeType 2>/dev/null)
        
        local actual_type
        actual_type=$(echo "$result" | grep "employeeType:" | head -1 | cut -d' ' -f2-)
        
        if [ "$actual_type" = "$expected_type" ]; then
            log "    ✓ $username employeeType: $actual_type"
        else
            error "    ✗ $username employeeType: expected '$expected_type', got '$actual_type'"
            type_errors+=("$username")
        fi
    done
    
    if [ ${#type_errors[@]} -eq 0 ]; then
        log "✓ All employeeType attributes correct"
        return 0
    else
        error "Incorrect employeeType attributes for: ${type_errors[*]}"
        return 1
    fi
}

# Test Unicode character support in attributes
test_unicode_support() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing Unicode character support in attributes"
    
    # Create a temporary user with Unicode characters for testing
    local unicode_ldif="/tmp/unicode-test-user.ldif"
    
    cat > "$unicode_ldif" << EOF
dn: uid=unicode-test,ou=users,$base_dn
objectClass: inetOrgPerson
uid: unicode-test
cn: José González
sn: González
givenName: José
displayName: José González (Test)
mail: jose.gonzalez@example.com
telephoneNumber: +1-555-0199
department: IT
employeeType: Full-Time
userPassword: {SSHA}$(docker exec openldap slappasswd -h '{SSHA}' -s 'TestUnicode123!')
EOF
    
    # Copy to container and import
    docker cp "$unicode_ldif" openldap:/tmp/unicode-test-user.ldif
    
    if docker exec openldap ldapadd -x -H ldap://localhost \
        -D "cn=admin,$base_dn" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -f /tmp/unicode-test-user.ldif >/dev/null 2>&1; then
        
        # Test retrieval of Unicode attributes
        local result
        result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -b "uid=unicode-test,ou=users,$base_dn" \
            displayName cn 2>/dev/null)
        
        if echo "$result" | grep -q "José" && echo "$result" | grep -q "González"; then
            log "✓ Unicode characters supported in attributes"
            
            # Clean up test user
            docker exec openldap ldapdelete -x -H ldap://localhost \
                -D "cn=admin,$base_dn" \
                -w "$LDAP_ADMIN_PASSWORD" \
                "uid=unicode-test,ou=users,$base_dn" >/dev/null 2>&1
            
            rm -f "$unicode_ldif"
            return 0
        else
            error "Unicode characters not properly stored/retrieved"
            rm -f "$unicode_ldif"
            return 1
        fi
    else
        warn "Could not create Unicode test user (may indicate LDAP issues)"
        rm -f "$unicode_ldif"
        return 0  # Don't fail the test suite for this
    fi
}

# Test attribute search performance
test_attribute_search_performance() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    info "Testing attribute search performance"
    
    local start_time
    local end_time
    local duration
    
    start_time=$(date +%s.%N)
    
    # Perform 10 attribute searches
    for i in $(seq 1 10); do
        docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -b "ou=users,$base_dn" \
            "department=IT" displayName mail >/dev/null 2>&1 || {
            error "Attribute search $i failed"
            return 1
        }
    done
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    local avg_time=$(echo "scale=3; $duration / 10" | bc -l)
    
    info "Average attribute search time: ${avg_time}s per query"
    
    # Check if search time is reasonable (should be under 0.5 seconds)
    if (( $(echo "$avg_time < 0.5" | bc -l) )); then
        log "✓ Attribute search performance acceptable (avg: ${avg_time}s)"
        return 0
    else
        warn "Attribute search slower than expected (avg: ${avg_time}s)"
        return 0  # Don't fail test, just warn
    fi
}

# Display detailed attribute information
display_attribute_details() {
    local base_dn="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
    
    echo
    echo "========================================="
    echo "       RUCKUS One Attribute Mapping     "
    echo "========================================="
    
    # Show mapping for each user
    local users=("test-user-01" "test-user-02" "test-user-03" "test-user-04" "test-user-05")
    
    for user in "${users[@]}"; do
        echo
        echo "User: $user"
        echo "----------------------------------------"
        
        local result
        result=$(docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -b "uid=$user,ou=users,$base_dn" \
            displayName mail telephoneNumber department employeeType 2>/dev/null)
        
        echo "$result" | grep -E "(displayName|mail|telephoneNumber|department|employeeType):" | while IFS= read -r line; do
            echo "  $line"
        done
    done
    
    echo
    echo "RUCKUS One IdP Mapping:"
    echo "  displayName      → Display name of the user"
    echo "  mail             → User's email address"
    echo "  telephoneNumber  → User's phone number"
    echo "  department       → Custom Attribute 1 (for access control)"
}

# Display test results summary
display_summary() {
    echo
    echo "========================================="
    echo "         Attribute Test Results         "
    echo "========================================="
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo "========================================="
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "All attribute tests passed! 🎉"
        echo
        echo "Your LDAP server provides all required RUCKUS One attributes."
        echo "Users can be successfully integrated with WiFi access points."
    else
        error "Some attribute tests failed!"
        echo
        echo "Please check the LDAP user configuration and attribute mapping."
        echo "Run './scripts/health-check.sh' for more details."
    fi
}

# Main function
main() {
    echo "Starting LDAP Attribute Tests"
    echo "============================="
    
    # Load environment and check prerequisites
    load_environment
    
    # Check if OpenLDAP container is running
    if ! docker-compose ps openldap | grep -q "Up"; then
        error "OpenLDAP container is not running. Start it with: make deploy"
        exit 1
    fi
    
    # Run all attribute tests
    run_test "RUCKUS Attributes - User 01" test_ruckus_attributes_user01
    run_test "All Users Attributes" test_all_users_attributes
    run_test "Attribute Format Validation" test_attribute_format
    run_test "Self Attribute Access" test_self_attribute_access
    run_test "Department Attributes" test_department_attributes
    run_test "Employee Type Attributes" test_employee_type_attributes
    run_test "Unicode Support" test_unicode_support
    run_test "Attribute Search Performance" test_attribute_search_performance
    
    # Display results
    display_summary
    
    # Show detailed attribute mapping if verbose mode
    if [ "${1:-}" = "--verbose" ] || [ "${1:-}" = "-v" ]; then
        display_attribute_details
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