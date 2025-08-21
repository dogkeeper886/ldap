#!/bin/bash

# Script to add Microsoft AD-compatible attributes for WiFi AP authentication
# This enables LDAP to work with access points expecting AD-style attributes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Convert domain to DN format
convert_domain_to_dn() {
    echo "$1" | sed 's/\./,dc=/g' | sed 's/^/dc=/'
}

LDAP_BASE_DN=$(convert_domain_to_dn "$LDAP_DOMAIN")

echo -e "${GREEN}Adding Microsoft AD-compatible attributes to LDAP...${NC}"
echo "Domain: $LDAP_DOMAIN"
echo "Base DN: $LDAP_BASE_DN"

# Step 1: Add the schema (requires cn=config access)
echo -e "\n${YELLOW}Step 1: Adding MS AD compatibility schema...${NC}"
docker exec -i openldap ldapadd -Y EXTERNAL -H ldapi:/// <<EOF || true
# Microsoft AD Compatibility Schema Extensions
dn: cn=msad-compat,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: msad-compat
olcAttributeTypes: ( 1.2.840.113556.1.4.221
  NAME 'sAMAccountName'
  DESC 'Windows NT4 logon name'
  EQUALITY caseIgnoreMatch
  SUBSTR caseIgnoreSubstringsMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.656
  NAME 'userPrincipalName'
  DESC 'Windows 2000+ logon name'
  EQUALITY caseIgnoreMatch
  SUBSTR caseIgnoreSubstringsMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.2.102
  NAME 'memberOf'
  DESC 'Group membership for authorization'
  EQUALITY distinguishedNameMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.12 )
olcAttributeTypes: ( 1.2.840.113556.1.4.159
  NAME 'accountExpires'
  DESC 'Account expiration date'
  EQUALITY integerMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.27
  SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.8
  NAME 'userAccountControl'
  DESC 'Account control flags'
  EQUALITY integerMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.27
  SINGLE-VALUE )
olcObjectClasses: ( 1.2.840.113556.1.5.9
  NAME 'msadUser'
  DESC 'Microsoft AD Compatible User'
  SUP top AUXILIARY
  MAY ( sAMAccountName $ userPrincipalName $ memberOf $ 
        accountExpires $ userAccountControl ) )
EOF

# Step 2: Create WiFi groups if they don't exist
echo -e "\n${YELLOW}Step 2: Creating WiFi access groups...${NC}"
docker exec -i openldap ldapadd -x -H ldap://localhost:389 \
    -D "cn=admin,${LDAP_BASE_DN}" -w "${LDAP_ADMIN_PASSWORD}" <<EOF || true
# WiFi Users Group
dn: cn=wifi-users,ou=groups,${LDAP_BASE_DN}
objectClass: top
objectClass: groupOfNames
cn: wifi-users
description: Standard WiFi network access
member: uid=test-user-01,ou=users,${LDAP_BASE_DN}

# WiFi Guests Group
dn: cn=wifi-guests,ou=groups,${LDAP_BASE_DN}
objectClass: top
objectClass: groupOfNames
cn: wifi-guests
description: Guest WiFi network access
member: uid=test-user-02,ou=users,${LDAP_BASE_DN}

# WiFi Admins Group
dn: cn=wifi-admins,ou=groups,${LDAP_BASE_DN}
objectClass: top
objectClass: groupOfNames
cn: wifi-admins
description: Administrative WiFi network access
member: uid=test-user-03,ou=users,${LDAP_BASE_DN}
EOF

# Step 3: Add MS AD attributes to existing users
echo -e "\n${YELLOW}Step 3: Adding MS AD attributes to users...${NC}"

# For each test user
for i in {01..03}; do
    USER="test-user-${i}"
    echo "Processing $USER..."
    
    # Determine group based on user number
    case $i in
        01) GROUP="wifi-users" ;;
        02) GROUP="wifi-guests" ;;
        03) GROUP="wifi-admins" ;;
    esac
    
    docker exec -i openldap ldapmodify -x -H ldap://localhost:389 \
        -D "cn=admin,${LDAP_BASE_DN}" -w "${LDAP_ADMIN_PASSWORD}" <<EOF || true
dn: uid=${USER},ou=users,${LDAP_BASE_DN}
changetype: modify
add: objectClass
objectClass: msadUser
-
add: sAMAccountName
sAMAccountName: ${USER}
-
add: userPrincipalName
userPrincipalName: ${USER}@${LDAP_DOMAIN}
-
add: memberOf
memberOf: cn=${GROUP},ou=groups,${LDAP_BASE_DN}
-
add: userAccountControl
userAccountControl: 512
EOF
done

# Step 4: Verify the changes
echo -e "\n${YELLOW}Step 4: Verifying MS AD attributes...${NC}"
echo -e "\nChecking test-user-01 attributes:"
docker exec openldap ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,${LDAP_BASE_DN}" -w "${LDAP_ADMIN_PASSWORD}" \
    -b "uid=test-user-01,ou=users,${LDAP_BASE_DN}" \
    "(objectClass=*)" sAMAccountName userPrincipalName memberOf

echo -e "\n${GREEN}MS AD attributes successfully added!${NC}"
echo -e "\n${YELLOW}WiFi AP Configuration Guide:${NC}"
echo "=================================="
echo "LDAP Server: ${LDAP_DOMAIN}"
echo "Port: 636 (LDAPS) or 389 (LDAP)"
echo "Base DN: ${LDAP_BASE_DN}"
echo "Bind DN: cn=admin,${LDAP_BASE_DN}"
echo ""
echo "User Search Filter Options:"
echo "  1. By sAMAccountName: (sAMAccountName=%s)"
echo "  2. By userPrincipalName: (userPrincipalName=%s)"
echo "  3. Combined (like MS AD): (|(sAMAccountName=%s)(userPrincipalName=%s))"
echo ""
echo "Test Users:"
echo "  test-user-01 / TestPass123! (Standard Access)"
echo "  test-user-02 / TestPass456! (Guest Access)"
echo "  test-user-03 / GuestPass789! (Admin Access)"
echo ""
echo "Group-based Access Control:"
echo "  wifi-users: Standard network access"
echo "  wifi-guests: Guest network with restrictions"
echo "  wifi-admins: Full network privileges"