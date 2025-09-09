#!/bin/bash
set -euo pipefail

echo "Waiting for FreeRADIUS server to be ready..."
until docker exec freeradius-server radtest test testpass123 localhost 1812 testing123 >/dev/null 2>&1; do
    sleep 2
done

echo "FreeRADIUS server is ready. Updating user passwords..."

# Source environment variables
source .env

# Update user passwords in the running container
echo "Updating user passwords from .env..."

# Get the users file path inside the container
users_file="/etc/freeradius/3.0/mods-config/files/users"

# Update passwords using docker exec
docker exec freeradius-server bash -c "
    # Replace password placeholders with actual values from environment
    sed -i 's/{{TEST_USER_PASSWORD}}/${TEST_USER_PASSWORD:-testpass123}/g' $users_file
    sed -i 's/{{GUEST_USER_PASSWORD}}/${GUEST_USER_PASSWORD:-guestpass123}/g' $users_file  
    sed -i 's/{{ADMIN_USER_PASSWORD}}/${ADMIN_USER_PASSWORD:-adminpass123}/g' $users_file
    sed -i 's/{{CONTRACTOR_PASSWORD}}/${CONTRACTOR_PASSWORD:-contractorpass123}/g' $users_file
    sed -i 's/{{VIP_PASSWORD}}/${VIP_PASSWORD:-vippass123}/g' $users_file
    
    # Reload FreeRADIUS configuration
    kill -HUP \$(pgrep freeradius) || echo 'FreeRADIUS reload failed, may need restart'
"

echo "User password update complete!"
echo "Testing updated authentication..."

# Test a user to verify passwords work
if docker exec freeradius-server radtest test "${TEST_USER_PASSWORD:-testpass123}" localhost 1812 testing123 >/dev/null 2>&1; then
    echo "✓ User authentication test successful"
else
    echo "✗ User authentication test failed - may need container restart"
fi