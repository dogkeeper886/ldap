#!/bin/bash
# Wrapper entrypoint that starts OpenLDAP and then initializes users

# Run the original entrypoint in background
/container/tool/run &
LDAP_PID=$!

# Function to initialize users
init_users() {
    echo "[Entrypoint] Waiting for OpenLDAP to be ready..."
    # Wait for LDAP to be ready
    for i in {1..30}; do
        if ldapsearch -x -H ldap://localhost -b "" -s base &>/dev/null; then
            echo "[Entrypoint] OpenLDAP is ready, initializing users..."
            /custom-init.sh
            return 0
        fi
        sleep 2
    done
    echo "[Entrypoint] OpenLDAP failed to become ready"
    return 1
}

# Run user initialization in background after a delay
(sleep 10 && init_users) &

# Wait for the OpenLDAP process
wait $LDAP_PID