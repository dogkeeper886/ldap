#!/bin/bash
# Script: setup-users.sh
# Purpose: Set up test users with secure passwords in LDAP directory
# Usage: ./setup-users.sh

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
    
    if [ ! -f ".env" ]; then
        error ".env file not found. Copy .env.example to .env and configure it first"
        exit 1
    fi
    
    # Check if OpenLDAP container is running
    if ! docker-compose ps openldap | grep -q "Up"; then
        error "OpenLDAP container is not running. Start it with: make deploy"
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
    local required_vars=("LDAP_DOMAIN" "LDAP_ADMIN_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error "Required environment variable $var not set in .env file"
            exit 1
        fi
    done
    
    log "Environment loaded successfully"
}

# Generate SSHA password hash
generate_password_hash() {
    local password="$1"
    docker exec openldap slappasswd -h '{SSHA}' -s "$password"
}

# Wait for LDAP service to be ready
wait_for_ldap() {
    log "Waiting for LDAP service to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec openldap ldapsearch -x -H ldap://localhost -b "" -s base > /dev/null 2>&1; then
            log "LDAP service is ready"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts: LDAP not ready yet, waiting..."
        sleep 2
        ((attempt++))
    done
    
    error "LDAP service failed to become ready after $max_attempts attempts"
    exit 1
}

# Import base LDIF structure
import_base_structure() {
    log "Importing base directory structure..."
    
    docker exec openldap ldapadd -x -H ldap://localhost \
        -D "cn=admin,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -f /ldifs/01-base.ldif
    
    log "Base structure imported successfully"
}

# Create LDIF with password hashes
create_users_with_passwords() {
    log "Creating users LDIF with password hashes..."
    
    local temp_ldif="/tmp/users-with-passwords.ldif"
    
    # Copy base users LDIF
    cp ldifs/02-users.ldif "$temp_ldif"
    
    # Generate password hashes
    local test_user_hash
    local guest_user_hash
    local admin_user_hash
    local contractor_hash
    local vip_hash
    
    test_user_hash=$(generate_password_hash "${TEST_USER_PASSWORD:-TestPass123!}")
    guest_user_hash=$(generate_password_hash "${GUEST_USER_PASSWORD:-GuestPass789!}")
    admin_user_hash=$(generate_password_hash "${ADMIN_USER_PASSWORD:-AdminPass456!}")
    contractor_hash=$(generate_password_hash "${CONTRACTOR_PASSWORD:-ContractorPass321!}")
    vip_hash=$(generate_password_hash "${VIP_PASSWORD:-VipPass654!}")
    
    # Replace password placeholders with actual hashes
    sed -i "s|# userPassword will be set via script|userPassword: $test_user_hash|" "$temp_ldif"
    
    # Add passwords for each user (need to be more specific)
    awk -v test_hash="$test_user_hash" \
        -v guest_hash="$guest_user_hash" \
        -v admin_hash="$admin_user_hash" \
        -v contractor_hash="$contractor_hash" \
        -v vip_hash="$vip_hash" '
    /uid: test-user-01/ { user = "test" }
    /uid: test-user-02/ { user = "guest" }
    /uid: test-user-03/ { user = "admin" }
    /uid: test-user-04/ { user = "contractor" }
    /uid: test-user-05/ { user = "vip" }
    /# userPassword will be set via script/ {
        if (user == "test") print "userPassword: " test_hash
        else if (user == "guest") print "userPassword: " guest_hash
        else if (user == "admin") print "userPassword: " admin_hash
        else if (user == "contractor") print "userPassword: " contractor_hash
        else if (user == "vip") print "userPassword: " vip_hash
        user = ""
        next
    }
    { print }
    ' ldifs/02-users.ldif > "$temp_ldif"
    
    # Copy to container
    docker cp "$temp_ldif" openldap:/tmp/users-with-passwords.ldif
    
    # Clean up
    rm "$temp_ldif"
    
    log "Users LDIF with passwords created"
}

# Import users with passwords
import_users() {
    log "Importing users with passwords..."
    
    docker exec openldap ldapadd -x -H ldap://localhost \
        -D "cn=admin,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -f /tmp/users-with-passwords.ldif
    
    log "Users imported successfully"
}

# Import groups
import_groups() {
    log "Importing groups..."
    
    docker exec openldap ldapadd -x -H ldap://localhost \
        -D "cn=admin,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -f /ldifs/03-groups.ldif
    
    log "Groups imported successfully"
}

# Verify user creation
verify_users() {
    log "Verifying user creation..."
    
    local users=("test-user-01" "test-user-02" "test-user-03" "test-user-04" "test-user-05")
    
    for user in "${users[@]}"; do
        if docker exec openldap ldapsearch -x -H ldap://localhost \
            -D "cn=admin,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -b "ou=users,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" \
            "uid=$user" | grep -q "dn: uid=$user"; then
            log "✓ User $user created successfully"
        else
            error "✗ User $user creation failed"
            exit 1
        fi
    done
    
    log "All users verified successfully"
}

# Test user authentication
test_authentication() {
    log "Testing user authentication..."
    
    # Test with test-user-01
    if docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "uid=test-user-01,ou=users,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" \
        -w "${TEST_USER_PASSWORD:-TestPass123!}" \
        -b "" -s base > /dev/null 2>&1; then
        log "✓ Authentication test passed for test-user-01"
    else
        error "✗ Authentication test failed for test-user-01"
        exit 1
    fi
    
    # Test with admin user
    if docker exec openldap ldapsearch -x -H ldap://localhost \
        -D "uid=test-user-03,ou=users,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" \
        -w "${ADMIN_USER_PASSWORD:-AdminPass456!}" \
        -b "" -s base > /dev/null 2>&1; then
        log "✓ Authentication test passed for test-user-03 (admin)"
    else
        error "✗ Authentication test failed for test-user-03 (admin)"
        exit 1
    fi
    
    log "Authentication tests passed"
}

# Display summary
display_summary() {
    log "User setup completed successfully!"
    echo
    echo "=== Test User Summary ==="
    echo "test-user-01 (IT Employee):     Password: ${TEST_USER_PASSWORD:-TestPass123!}"
    echo "test-user-02 (Guest):           Password: ${GUEST_USER_PASSWORD:-GuestPass789!}"
    echo "test-user-03 (Admin):           Password: ${ADMIN_USER_PASSWORD:-AdminPass456!}"
    echo "test-user-04 (Contractor):      Password: ${CONTRACTOR_PASSWORD:-ContractorPass321!}"
    echo "test-user-05 (VIP):             Password: ${VIP_PASSWORD:-VipPass654!}"
    echo
    echo "Users can be tested with:"
    echo "ldapsearch -x -H ldaps://$LDAP_DOMAIN:636 -D 'uid=test-user-01,ou=users,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}' -w '${TEST_USER_PASSWORD:-TestPass123!}' -b '' -s base"
}

# Main function
main() {
    log "Starting user setup..."
    
    check_prerequisites
    load_environment
    wait_for_ldap
    
    # Import data in order
    import_base_structure || warn "Base structure may already exist"
    create_users_with_passwords
    import_users || warn "Users may already exist"
    import_groups || warn "Groups may already exist"
    
    verify_users
    test_authentication
    display_summary
    
    log "User setup completed successfully!"
}

# Run main function
main "$@"