#!/bin/bash
# Automated user initialization script for test LDAP
# This runs automatically when the container starts

set -e

echo "[Bootstrap] Starting automated user initialization..."

# Wait for LDAP to be ready
wait_for_ldap() {
    echo "[Bootstrap] Waiting for LDAP service..."
    for i in {1..30}; do
        if ldapsearch -x -H ldap://localhost -b "" -s base &>/dev/null; then
            echo "[Bootstrap] LDAP service is ready"
            return 0
        fi
        sleep 2
    done
    echo "[Bootstrap] ERROR: LDAP service failed to start"
    return 1
}

# Check if users already exist
check_users_exist() {
    ldapsearch -x -H ldap://localhost \
        -D "cn=admin,$LDAP_BASE_DN" \
        -w "$LDAP_ADMIN_PASSWORD" \
        -b "ou=users,$LDAP_BASE_DN" \
        "(objectClass=inetOrgPerson)" 2>/dev/null | grep -q "dn:" || return 1
    return 0
}

# Initialize test users
init_users() {
    echo "[Bootstrap] Initializing test users..."
    
    # Create base DN from domain
    DOMAIN_PARTS=(${LDAP_DOMAIN//./ })
    LDAP_BASE_DN=""
    for part in "${DOMAIN_PARTS[@]}"; do
        if [ -n "$LDAP_BASE_DN" ]; then
            LDAP_BASE_DN="${LDAP_BASE_DN},"
        fi
        LDAP_BASE_DN="${LDAP_BASE_DN}dc=${part}"
    done
    
    # Skip if users already exist
    if check_users_exist; then
        echo "[Bootstrap] Users already exist, skipping initialization"
        return 0
    fi
    
    echo "[Bootstrap] Creating organizational units..."
    
    # Create OUs
    cat <<EOF | ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" -c 2>/dev/null || true
dn: ou=users,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: users

dn: ou=groups,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: groups
EOF
    
    echo "[Bootstrap] Creating test users with predefined passwords..."
    
    # Define test users with fixed passwords for testing
    declare -A users=(
        ["wifi-user"]="WiFiPass123!"
        ["test-user"]="TestPass456!"
        ["admin-user"]="AdminPass789!"
        ["guest-user"]="GuestPass000!"
        ["vip-user"]="VipPass111!"
    )
    
    # Create each user
    for username in "${!users[@]}"; do
        password="${users[$username]}"
        echo "[Bootstrap] Creating user: $username"
        
        cat <<EOF | ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" 2>/dev/null || true
dn: uid=$username,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: $username
cn: $username
sn: User
givenName: Test
mail: $username@$LDAP_DOMAIN
userPassword: $password
EOF
    done
    
    echo "[Bootstrap] Creating WiFi groups..."
    
    # Create groups for different access levels
    cat <<EOF | ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" -c 2>/dev/null || true
dn: cn=wifi-users,ou=groups,$LDAP_BASE_DN
objectClass: groupOfNames
cn: wifi-users
member: uid=wifi-user,ou=users,$LDAP_BASE_DN
member: uid=test-user,ou=users,$LDAP_BASE_DN
member: uid=admin-user,ou=users,$LDAP_BASE_DN
member: uid=vip-user,ou=users,$LDAP_BASE_DN

dn: cn=guest-wifi,ou=groups,$LDAP_BASE_DN
objectClass: groupOfNames
cn: guest-wifi
member: uid=guest-user,ou=users,$LDAP_BASE_DN

dn: cn=admin-wifi,ou=groups,$LDAP_BASE_DN
objectClass: groupOfNames
cn: admin-wifi
member: uid=admin-user,ou=users,$LDAP_BASE_DN
EOF
    
    echo "[Bootstrap] Test users created successfully!"
    echo "[Bootstrap] ======================================="
    echo "[Bootstrap] Test User Credentials:"
    echo "[Bootstrap] wifi-user  : WiFiPass123!"
    echo "[Bootstrap] test-user  : TestPass456!"
    echo "[Bootstrap] admin-user : AdminPass789!"
    echo "[Bootstrap] guest-user : GuestPass000!"
    echo "[Bootstrap] vip-user   : VipPass111!"
    echo "[Bootstrap] ======================================="
}

# Main execution
wait_for_ldap && init_users

echo "[Bootstrap] User initialization complete"