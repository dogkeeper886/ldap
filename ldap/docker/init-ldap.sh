#!/bin/bash
set -euo pipefail

# Wait for LDAP service
sleep 10

# Import LDIF files
base_dn="dc=${LDAP_DOMAIN//./,dc=}"

for ldif_file in /ldifs/*.ldif; do
    if [ -f "$ldif_file" ]; then
        temp_file="/tmp/$(basename "$ldif_file")"
        sed "s/dc=example,dc=com/$base_dn/g" "$ldif_file" > "$temp_file"

        ldapadd -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" \
            -f "$temp_file" || true

        rm -f "$temp_file"
    fi
done

# Set user passwords
users=(
    "test-user-01:TEST_USER_PASSWORD"
    "test-user-02:GUEST_USER_PASSWORD"
    "test-user-03:ADMIN_USER_PASSWORD"
    "test-user-04:CONTRACTOR_PASSWORD"
    "test-user-05:VIP_PASSWORD"
)

for user_info in "${users[@]}"; do
    username="${user_info%%:*}"
    password_var="${user_info#*:}"
    password="${!password_var:-}"

    if [ -n "$password" ]; then
        password_hash=$(slappasswd -h '{SSHA}' -s "$password")

        echo "dn: uid=$username,ou=users,$base_dn
changetype: modify
replace: userPassword
userPassword: $password_hash" | ldapmodify -x -H ldap://localhost \
            -D "cn=admin,$base_dn" \
            -w "$LDAP_ADMIN_PASSWORD" || true
    fi
done
