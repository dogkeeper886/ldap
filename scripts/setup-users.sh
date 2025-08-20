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

# Add base directory structure
log "Adding base LDAP structure..."
docker exec openldap ldapadd -x -D "cn=admin,dc=example,dc=com" -w "$LDAP_ADMIN_PASSWORD" -f /ldifs/01-base.ldif || true

# Add test users
log "Adding test users..."
docker exec openldap ldapadd -x -D "cn=admin,dc=example,dc=com" -w "$LDAP_ADMIN_PASSWORD" -f /ldifs/02-users.ldif || true

# Add groups
log "Adding groups..."
docker exec openldap ldapadd -x -D "cn=admin,dc=example,dc=com" -w "$LDAP_ADMIN_PASSWORD" -f /ldifs/03-groups.ldif || true

log "LDAP users setup completed"