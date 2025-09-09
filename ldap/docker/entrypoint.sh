#!/bin/bash
set -euo pipefail

# Initialize LDAP data on first run
if [ ! -f "/tmp/.ldap-initialized" ]; then
    /opt/ldap-scripts/init-ldap.sh &
    touch "/tmp/.ldap-initialized"
fi

exec /container/tool/run "$@"
