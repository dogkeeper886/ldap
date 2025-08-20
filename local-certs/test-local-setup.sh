#!/bin/bash
# Test script for local LDAP setup

set -e

DOMAIN_DN="dc=ldap,dc=tsengsyu,dc=com"
ADMIN_DN="cn=admin,$DOMAIN_DN"
ADMIN_PASSWORD="SecureAdmin123!"

echo "Testing admin authentication..."
docker exec openldap-proper ldapwhoami -x -H ldap://localhost -D "$ADMIN_DN" -w "$ADMIN_PASSWORD"

echo "Creating users OU..."
echo "dn: ou=users,$DOMAIN_DN
objectClass: organizationalUnit
ou: users" | docker exec -i openldap-proper ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$ADMIN_PASSWORD"

echo "Creating test user..."
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
ou: IT" | docker exec -i openldap-proper ldapadd -x -H ldap://localhost -D "$ADMIN_DN" -w "$ADMIN_PASSWORD"

echo "Setting password for test user..."
docker exec openldap-proper ldappasswd -x -H ldap://localhost -D "$ADMIN_DN" -w "$ADMIN_PASSWORD" -s "TestPass123!" "uid=test-user-01,ou=users,$DOMAIN_DN"

echo "Testing user authentication..."
docker exec openldap-proper ldapwhoami -x -H ldap://localhost -D "uid=test-user-01,ou=users,$DOMAIN_DN" -w "TestPass123!"

echo "All tests completed successfully!"