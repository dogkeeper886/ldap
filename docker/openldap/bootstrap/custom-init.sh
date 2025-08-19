#!/bin/bash
# This script runs after OpenLDAP starts and initializes test users

# Wait a bit for slapd to be fully ready
sleep 5

# Check if marker file exists (to prevent re-running)
if [ -f /var/lib/ldap/.users_initialized ]; then
    echo "[Custom Init] Users already initialized, skipping..."
    exit 0
fi

echo "[Custom Init] Initializing test users for LDAP..."

# Extract domain components
DOMAIN_PARTS=(${LDAP_DOMAIN//./ })
LDAP_BASE_DN=""
for part in "${DOMAIN_PARTS[@]}"; do
    if [ -n "$LDAP_BASE_DN" ]; then
        LDAP_BASE_DN="${LDAP_BASE_DN},"
    fi
    LDAP_BASE_DN="${LDAP_BASE_DN}dc=${part}"
done

echo "[Custom Init] Using Base DN: $LDAP_BASE_DN"

# Create OUs
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: ou=users,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: users

dn: ou=groups,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: groups
EOF

# Create test users
echo "[Custom Init] Creating test users..."

# User 1: wifi-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=wifi-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: wifi-user
cn: WiFi User
sn: User
givenName: WiFi
mail: wifi-user@$LDAP_DOMAIN
userPassword: WiFiPass123!
EOF

# User 2: test-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=test-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: test-user
cn: Test User
sn: User
givenName: Test
mail: test-user@$LDAP_DOMAIN
userPassword: TestPass456!
EOF

# User 3: admin-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=admin-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: admin-user
cn: Admin User
sn: User
givenName: Admin
mail: admin-user@$LDAP_DOMAIN
userPassword: AdminPass789!
EOF

# User 4: guest-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=guest-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: guest-user
cn: Guest User
sn: User
givenName: Guest
mail: guest-user@$LDAP_DOMAIN
userPassword: GuestPass000!
EOF

# User 5: vip-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=vip-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: vip-user
cn: VIP User
sn: User
givenName: VIP
mail: vip-user@$LDAP_DOMAIN
userPassword: VipPass111!
EOF

# Create groups
echo "[Custom Init] Creating groups..."

ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
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

# Create marker file
touch /var/lib/ldap/.users_initialized

echo "[Custom Init] Test users created successfully!"
echo "============================================"
echo "Test User Credentials:"
echo "  wifi-user  : WiFiPass123!"
echo "  test-user  : TestPass456!"
echo "  admin-user : AdminPass789!"
echo "  guest-user : GuestPass000!"
echo "  vip-user   : VipPass111!"
echo "============================================"