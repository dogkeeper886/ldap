#!/bin/bash
set -euo pipefail

# This runs after the default osixia/openldap initialization
# Wait a moment for slapd to be ready
sleep 5

# Run our custom initialization in background
if [ ! -f "/tmp/.custom-users-initialized" ]; then
    echo "***  INFO   | $(date +"%Y-%m-%d %H:%M:%S") | Running custom user initialization..."
    /opt/ldap-scripts/init-ldap.sh &
    touch "/tmp/.custom-users-initialized"
fi