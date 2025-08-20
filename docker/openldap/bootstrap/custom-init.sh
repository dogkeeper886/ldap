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
objectClass: top
uid: wifi-user
cn: WiFi User
sn: User
givenName: WiFi
displayName: WiFi Test User
mail: wifi-user@$LDAP_DOMAIN
telephoneNumber: +1-555-0101
mobile: +1-555-9101
title: Network Test User
departmentNumber: IT001
ou: IT Department
employeeNumber: EMP001
employeeType: Full-Time
description: Test user for WiFi authentication
street: 123 Test Street
l: San Francisco
st: CA
postalCode: 94102
preferredLanguage: en-US
EOF
ldappasswd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" -s "WiFiPass123!" "uid=wifi-user,ou=users,$LDAP_BASE_DN" 2>/dev/null || true

# User 2: test-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=test-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: test-user
cn: Test User
sn: User
givenName: Test
displayName: Test Development User
mail: test-user@$LDAP_DOMAIN
telephoneNumber: +1-555-0102
mobile: +1-555-9102
title: Software Developer
departmentNumber: DEV001
ou: Development Team
employeeNumber: EMP002
employeeType: Full-Time
description: Test user for development testing
street: 456 Dev Avenue
l: Austin
st: TX
postalCode: 78701
preferredLanguage: en-US
EOF
ldappasswd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" -s "TestPass456!" "uid=test-user,ou=users,$LDAP_BASE_DN" 2>/dev/null || true

# User 3: admin-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=admin-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: admin-user
cn: Admin User
sn: User
givenName: Admin
displayName: System Administrator
mail: admin-user@$LDAP_DOMAIN
telephoneNumber: +1-555-0103
mobile: +1-555-9103
title: Senior System Administrator
departmentNumber: IT002
ou: IT Operations
employeeNumber: EMP003
employeeType: Full-Time
description: Administrative user with elevated privileges
street: 789 Admin Plaza
l: Seattle
st: WA
postalCode: 98101
preferredLanguage: en-US
EOF
ldappasswd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" -s "AdminPass789!" "uid=admin-user,ou=users,$LDAP_BASE_DN" 2>/dev/null || true

# User 4: guest-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=guest-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: guest-user
cn: Guest User
sn: User
givenName: Guest
displayName: Guest Access User
mail: guest-user@$LDAP_DOMAIN
telephoneNumber: +1-555-0104
mobile: +1-555-9104
title: Visitor
departmentNumber: EXT001
ou: External
employeeNumber: GUEST001
employeeType: Temporary
description: Temporary guest access for visitors
street: 321 Visitor Lane
l: New York
st: NY
postalCode: 10001
preferredLanguage: en-US
EOF
ldappasswd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" -s "GuestPass000!" "uid=guest-user,ou=users,$LDAP_BASE_DN" 2>/dev/null || true

# User 5: vip-user
ldapadd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF 2>/dev/null || true
dn: uid=vip-user,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: vip-user
cn: VIP User
sn: User
givenName: VIP
displayName: VIP Executive User
mail: vip-user@$LDAP_DOMAIN
telephoneNumber: +1-555-0105
mobile: +1-555-9105
title: Chief Executive Officer
departmentNumber: EXEC001
ou: Executive Management
employeeNumber: EMP005
employeeType: Executive
description: VIP user with premium access privileges
street: 999 Executive Drive
l: Los Angeles
st: CA
postalCode: 90001
preferredLanguage: en-US
EOF
ldappasswd -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w "$LDAP_ADMIN_PASSWORD" -s "VipPass111!" "uid=vip-user,ou=users,$LDAP_BASE_DN" 2>/dev/null || true

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