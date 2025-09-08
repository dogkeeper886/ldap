#!/bin/bash
# Test all configured FreeRADIUS users

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Colors for logging
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[UserTest] $1${NC}"
}

error() {
    echo -e "${RED}[UserTest] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[UserTest] WARNING: $1${NC}"
}

# Test users configuration
declare -A TEST_USERS=(
    ["test"]="${TEST_USER_PASSWORD:-testpass123}"
    ["guest"]="${GUEST_USER_PASSWORD:-guestpass123}"
    ["admin"]="${ADMIN_USER_PASSWORD:-adminpass123}"
    ["contractor"]="${CONTRACTOR_PASSWORD:-contractorpass123}"
    ["vip"]="${VIP_PASSWORD:-vippass123}"
)

log "Testing all configured FreeRADIUS users..."
echo "=========================================="

# Check if radtest is available
if command -v radtest >/dev/null 2>&1; then
    RADTEST_CMD="radtest"
else
    RADTEST_CMD="docker exec freeradius-server radtest"
    log "Using radtest from FreeRADIUS container"
fi

# Test each user
success_count=0
total_count=${#TEST_USERS[@]}

for username in "${!TEST_USERS[@]}"; do
    password="${TEST_USERS[$username]}"
    
    echo ""
    log "Testing user: $username"
    echo "Command: $RADTEST_CMD $username [password] localhost 1812 testing123"
    
    if $RADTEST_CMD "$username" "$password" localhost 1812 testing123 >/dev/null 2>&1; then
        log "✓ $username authentication SUCCESS"
        ((success_count++))
    else
        error "✗ $username authentication FAILED"
        # Show detailed output for failed attempts
        log "Detailed output:"
        $RADTEST_CMD "$username" "$password" localhost 1812 testing123 || true
    fi
done

echo ""
echo "=========================================="
log "Test Summary: $success_count/$total_count users authenticated successfully"

if [ $success_count -eq $total_count ]; then
    log "✓ All user tests passed!"
    exit 0
else
    error "✗ Some user tests failed. Check FreeRADIUS logs: make logs"
    exit 1
fi