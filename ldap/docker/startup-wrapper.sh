#!/bin/bash
# Run initialization after container fully starts
(
    # Wait for slapd to be ready
    while ! ldapsearch -x -H ldap://localhost -b "" -s base >/dev/null 2>&1; do
        sleep 2
    done
    
    # Run initialization if not already done
    if [ ! -f "/tmp/.users-initialized" ]; then
        echo "Running user initialization..."
        /opt/ldap-scripts/init-ldap.sh
        touch "/tmp/.users-initialized"
    fi
) &