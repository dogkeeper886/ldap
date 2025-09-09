#!/bin/bash
set -euo pipefail

echo "Waiting for LDAP server to be ready..."
until docker exec openldap ldapsearch -x -H ldap://localhost -b "" -s base >/dev/null 2>&1; do
    sleep 2
done

echo "LDAP server is ready. Setting up users..."

# Get base DN from environment
source .env
base_dn="dc=${LDAP_DOMAIN//./,dc=}"

# Import LDIF files in order
for ldif_file in ldifs/*.ldif; do
    if [ -f "$ldif_file" ]; then
        filename=$(basename "$ldif_file")
        echo "Importing $filename..."
        
        # Replace example.com with actual domain and import
        sed "s/dc=example,dc=com/$base_dn/g" "$ldif_file" | \
            docker exec -i openldap ldapadd -x -H ldap://localhost \
                -D "cn=admin,$base_dn" \
                -w "$LDAP_ADMIN_PASSWORD" -c 2>&1 | \
            grep -v "ldap_add: Already exists" || true
    fi
done

# Set user passwords using ldappasswd
echo "Setting user passwords..."
docker exec openldap ldappasswd -x -H ldap://localhost \
    -D "cn=admin,$base_dn" -w "$LDAP_ADMIN_PASSWORD" \
    -s "$TEST_USER_PASSWORD" "uid=test-user-01,ou=users,$base_dn"

docker exec openldap ldappasswd -x -H ldap://localhost \
    -D "cn=admin,$base_dn" -w "$LDAP_ADMIN_PASSWORD" \
    -s "$GUEST_USER_PASSWORD" "uid=test-user-02,ou=users,$base_dn"

docker exec openldap ldappasswd -x -H ldap://localhost \
    -D "cn=admin,$base_dn" -w "$LDAP_ADMIN_PASSWORD" \
    -s "$ADMIN_USER_PASSWORD" "uid=test-user-03,ou=users,$base_dn"

docker exec openldap ldappasswd -x -H ldap://localhost \
    -D "cn=admin,$base_dn" -w "$LDAP_ADMIN_PASSWORD" \
    -s "$CONTRACTOR_PASSWORD" "uid=test-user-04,ou=users,$base_dn"

docker exec openldap ldappasswd -x -H ldap://localhost \
    -D "cn=admin,$base_dn" -w "$LDAP_ADMIN_PASSWORD" \
    -s "$VIP_PASSWORD" "uid=test-user-05,ou=users,$base_dn"

echo "User setup complete!"