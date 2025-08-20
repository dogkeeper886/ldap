#!/bin/bash
# Script: setup-users.sh
# Purpose: Set up test users in LDAP directory

set -e

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Load environment variables
source .env

log "Setting up LDAP test users..."

# Wait for LDAP to be ready
log "Waiting for LDAP service..."
sleep 5

# Convert domain to DN (Option 1 approach)
DOMAIN_DN=$(echo "$LDAP_DOMAIN" | sed 's/\\./,dc=/g' | sed 's/^/dc=/')
ADMIN_DN="cn=admin,$DOMAIN_DN"

log "Using domain: $DOMAIN_DN"

# 1. Create base domain
log "1. Creating base domain..."
echo "dn: $DOMAIN_DN
objectClass: top
objectClass: dcObject
objectClass: organization
o: $LDAP_ORG
dc: $(echo $DOMAIN_DN | cut -d, -f1 | cut -d= -f2)" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

# 2. Create OUs
log "2. Creating organizational units..."
echo "dn: ou=users,$DOMAIN_DN
objectClass: organizationalUnit
ou: users" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

echo "dn: ou=groups,$DOMAIN_DN
objectClass: organizationalUnit
ou: groups" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

# 3. Create test users (without passwords)
log "3. Creating test users..."

# John Smith - IT Administrator
echo "dn: uid=test-user-01,ou=users,$DOMAIN_DN
objectClass: inetOrgPerson
uid: test-user-01
cn: John Smith
sn: Smith
givenName: John
displayName: John Smith
mail: john.smith@example.com
telephoneNumber: +1-555-0101
mobile: +1-555-1001
title: IT Administrator
ou: IT" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

# Jane Doe - Network Engineer
echo "dn: uid=test-user-02,ou=users,$DOMAIN_DN
objectClass: inetOrgPerson
uid: test-user-02
cn: Jane Doe
sn: Doe
givenName: Jane
displayName: Jane Doe
mail: jane.doe@example.com
telephoneNumber: +1-555-0102
mobile: +1-555-1002
title: Network Engineer
ou: IT" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

# Mike Johnson - Guest User
echo "dn: uid=test-user-03,ou=users,$DOMAIN_DN
objectClass: inetOrgPerson
uid: test-user-03
cn: Mike Johnson
sn: Johnson
givenName: Mike
displayName: Mike Johnson
mail: mike.johnson@example.com
telephoneNumber: +1-555-0103
mobile: +1-555-1003
title: Guest User
ou: Guest" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

# 4. Set passwords with ldappasswd
log "4. Setting passwords..."
sleep 2  # Wait for users to be fully created
docker exec openldap ldappasswd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -s "TestPass123!" "uid=test-user-01,ou=users,$DOMAIN_DN"
docker exec openldap ldappasswd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -s "TestPass456!" "uid=test-user-02,ou=users,$DOMAIN_DN"
docker exec openldap ldappasswd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -s "GuestPass789!" "uid=test-user-03,ou=users,$DOMAIN_DN"

# 5. Create groups
log "5. Creating groups..."

# IT group
echo "dn: cn=it-staff,ou=groups,$DOMAIN_DN
objectClass: groupOfNames
cn: it-staff
member: uid=test-user-01,ou=users,$DOMAIN_DN
member: uid=test-user-02,ou=users,$DOMAIN_DN" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

# Guest group
echo "dn: cn=guests,ou=groups,$DOMAIN_DN
objectClass: groupOfNames
cn: guests
member: uid=test-user-03,ou=users,$DOMAIN_DN" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

# All users group
echo "dn: cn=all-users,ou=groups,$DOMAIN_DN
objectClass: groupOfNames
cn: all-users
member: uid=test-user-01,ou=users,$DOMAIN_DN
member: uid=test-user-02,ou=users,$DOMAIN_DN
member: uid=test-user-03,ou=users,$DOMAIN_DN" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" || true

log "LDAP users setup completed successfully!"
log "Test users:"
log "  test-user-01 (John Smith) - TestPass123!"
log "  test-user-02 (Jane Doe) - TestPass456!"
log "  test-user-03 (Mike Johnson) - GuestPass789!"