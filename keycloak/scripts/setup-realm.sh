#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD}"
LDAP_HOST_VAR="${LDAP_HOST:-openldap}"
LDAP_PORT_VAR="${LDAP_PORT:-636}"

# Derive LDAP Base DN from domain
LDAP_BASE_DN="dc=${LDAP_DOMAIN//./,dc=}"

echo "Waiting for Keycloak to be ready..."
until curl -sf "$KEYCLOAK_URL/realms/master/.well-known/openid-configuration" > /dev/null 2>&1; do
    echo "Keycloak not ready yet, waiting..."
    sleep 5
done
echo "Keycloak is ready!"

echo "Obtaining admin token..."
TOKEN=$(curl -sf -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$ADMIN_USER" \
    -d "password=$ADMIN_PASS" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "Failed to obtain admin token"
    exit 1
fi
echo "Admin token obtained successfully"

# Check if realm already exists
REALM_EXISTS=$(curl -sf -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/admin/realms/saml-test" \
    -H "Authorization: Bearer $TOKEN" || echo "404")

if [ "$REALM_EXISTS" = "200" ]; then
    echo "Realm 'saml-test' already exists, skipping creation"
else
    echo "Creating SAML realm..."
    curl -sf -X POST "$KEYCLOAK_URL/admin/realms" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "realm": "saml-test",
            "enabled": true,
            "displayName": "SAML Test Realm",
            "sslRequired": "external"
        }'
    echo "Realm 'saml-test' created"
fi

# Determine LDAP connection URL
if [ "$LDAP_PORT_VAR" = "636" ]; then
    LDAP_CONNECTION_URL="ldaps://${LDAP_HOST_VAR}:${LDAP_PORT_VAR}"
else
    LDAP_CONNECTION_URL="ldap://${LDAP_HOST_VAR}:${LDAP_PORT_VAR}"
fi

echo "Configuring LDAP user federation..."
echo "  Connection URL: $LDAP_CONNECTION_URL"
echo "  Users DN: ou=users,$LDAP_BASE_DN"
echo "  Bind DN: cn=admin,$LDAP_BASE_DN"

# Check if LDAP federation already exists
LDAP_EXISTS=$(curl -sf "$KEYCLOAK_URL/admin/realms/saml-test/components?type=org.keycloak.storage.UserStorageProvider" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.name=="ldap") | .id' || echo "")

if [ -n "$LDAP_EXISTS" ]; then
    echo "LDAP federation already configured"
    LDAP_ID="$LDAP_EXISTS"
else
    curl -sf -X POST "$KEYCLOAK_URL/admin/realms/saml-test/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "ldap",
            "providerId": "ldap",
            "providerType": "org.keycloak.storage.UserStorageProvider",
            "config": {
                "enabled": ["true"],
                "priority": ["0"],
                "editMode": ["READ_ONLY"],
                "syncRegistrations": ["false"],
                "vendor": ["other"],
                "usernameLDAPAttribute": ["uid"],
                "rdnLDAPAttribute": ["uid"],
                "uuidLDAPAttribute": ["entryUUID"],
                "userObjectClasses": ["inetOrgPerson"],
                "connectionUrl": ["'"$LDAP_CONNECTION_URL"'"],
                "usersDn": ["ou=users,'"$LDAP_BASE_DN"'"],
                "bindDn": ["cn=admin,'"$LDAP_BASE_DN"'"],
                "bindCredential": ["'"$LDAP_ADMIN_PASSWORD"'"],
                "searchScope": ["1"],
                "useTruststoreSpi": ["ldapsOnly"],
                "connectionPooling": ["true"],
                "pagination": ["true"],
                "batchSizeForSync": ["1000"],
                "fullSyncPeriod": ["-1"],
                "changedSyncPeriod": ["-1"]
            }
        }'
    echo "LDAP federation created"

    # Get LDAP component ID
    LDAP_ID=$(curl -sf "$KEYCLOAK_URL/admin/realms/saml-test/components?type=org.keycloak.storage.UserStorageProvider" \
        -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.name=="ldap") | .id')
fi

echo "LDAP Component ID: $LDAP_ID"

# Function to add LDAP attribute mapper
add_ldap_mapper() {
    local name="$1"
    local ldap_attr="$2"
    local user_attr="$3"

    curl -sf -X POST "$KEYCLOAK_URL/admin/realms/saml-test/components" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "'"$name"'",
            "providerId": "user-attribute-ldap-mapper",
            "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
            "parentId": "'"$LDAP_ID"'",
            "config": {
                "ldap.attribute": ["'"$ldap_attr"'"],
                "user.model.attribute": ["'"$user_attr"'"],
                "read.only": ["true"],
                "always.read.value.from.ldap": ["true"],
                "is.mandatory.in.ldap": ["false"]
            }
        }' 2>/dev/null && echo "  - $name mapper added" || echo "  - $name mapper exists"
}

echo "Configuring LDAP attribute mappers..."

# Basic user attributes
add_ldap_mapper "email" "mail" "email"
add_ldap_mapper "firstName" "givenName" "firstName"
add_ldap_mapper "lastName" "sn" "lastName"
add_ldap_mapper "displayName" "displayName" "displayName"
add_ldap_mapper "phone" "telephoneNumber" "phone"

# Role and group attributes
add_ldap_mapper "title" "title" "title"
add_ldap_mapper "department" "ou" "department"
add_ldap_mapper "employeeType" "employeeType" "employeeType"
add_ldap_mapper "memberOf" "memberOf" "memberOf"

echo "LDAP attribute mappers configured!"

echo ""
echo "Setup complete!"
echo ""
echo "Access the admin console at: $KEYCLOAK_URL/admin"
echo "SAML Metadata URL: $KEYCLOAK_URL/realms/saml-test/protocol/saml/descriptor"
echo ""
echo "To sync LDAP users:"
echo "  1. Go to Admin Console > saml-test realm > User Federation > ldap"
echo "  2. Click 'Sync all users'"
