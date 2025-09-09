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

# Add MS AD schema first (using EXTERNAL auth for schema)
echo "Loading MS AD compatibility schema..."
docker exec openldap ldapadd -Y EXTERNAL -H ldapi:/// -f /ldifs/05-msad-compat.ldif 2>&1 | \
    grep -v "Duplicate attributeType" || true

# Import LDIF files in order (skip MS AD schema and user attributes for now)
for ldif_file in ldifs/*.ldif; do
    if [ -f "$ldif_file" ]; then
        filename=$(basename "$ldif_file")
        
        # Skip MS AD files - handle them separately
        if [[ "$filename" == "05-msad-compat.ldif" || "$filename" == "06-users-with-msad.ldif" ]]; then
            continue
        fi
        
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

# Apply MS AD compatibility attributes
echo "Adding MS AD compatibility attributes..."
sed "s/dc=example,dc=com/$base_dn/g" ldifs/06-users-with-msad.ldif | \
    docker exec -i openldap ldapmodify -x -H ldap://localhost \
        -D "cn=admin,$base_dn" \
        -w "$LDAP_ADMIN_PASSWORD" -c 2>&1 | \
    grep -v "Type or value exists" || true

echo "User setup complete!"