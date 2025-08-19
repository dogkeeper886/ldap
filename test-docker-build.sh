#!/bin/bash
# Script: test-docker-build.sh
# Purpose: Test the new Docker build setup
# Usage: ./test-docker-build.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[Test][$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[Test][$(date +'%H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[Test][$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[Test][$(date +'%H:%M:%S')] INFO: $1${NC}"
}

# Test Docker and Docker Compose
test_prerequisites() {
    log "Testing prerequisites..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker not found"
        return 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        error "Docker Compose not found"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon not running"
        return 1
    fi
    
    log "Prerequisites check passed"
    return 0
}

# Test environment setup
test_environment() {
    log "Testing environment setup..."
    
    if [ ! -f ".env.example" ]; then
        error ".env.example not found"
        return 1
    fi
    
    # Create test .env if it doesn't exist
    if [ ! -f ".env" ]; then
        log "Creating test .env file..."
        cp .env.example .env
        
        # Set test values
        sed -i 's/your-domain.com/test.example.com/' .env
        sed -i 's/admin@your-domain.com/test@example.com/' .env
        sed -i 's/your_very_secure_admin_password_here/TestAdminPass123!/' .env
        sed -i 's/your_very_secure_config_password_here/TestConfigPass123!/' .env
        sed -i 's/ENVIRONMENT=production/ENVIRONMENT=development/' .env
    fi
    
    log "Environment setup completed"
    return 0
}

# Test Docker image building
test_docker_build() {
    log "Testing Docker image building..."
    
    # Build images
    if docker-compose build --quiet; then
        log "Docker images built successfully"
    else
        error "Docker image build failed"
        return 1
    fi
    
    # Check if images were created
    if docker images | grep -q "ldap-openldap"; then
        log "OpenLDAP image created successfully"
    else
        error "OpenLDAP image not found"
        return 1
    fi
    
    if docker images | grep -q "ldap-certbot"; then
        log "Certbot image created successfully"
    else
        error "Certbot image not found"
        return 1
    fi
    
    return 0
}

# Test container startup (dry run)
test_container_startup() {
    log "Testing container configuration..."
    
    # Validate docker-compose configuration
    if docker-compose config >/dev/null 2>&1; then
        log "Docker Compose configuration is valid"
    else
        error "Docker Compose configuration is invalid"
        return 1
    fi
    
    # Test container creation (don't start services)
    if docker-compose create >/dev/null 2>&1; then
        log "Container creation test passed"
        
        # Clean up test containers
        docker-compose down >/dev/null 2>&1 || true
        
        return 0
    else
        error "Container creation failed"
        return 1
    fi
}

# Test script executability
test_scripts() {
    log "Testing script executability..."
    
    local scripts=(
        "docker/openldap/entrypoint.sh"
        "docker/openldap/health-check.sh"
        "docker/openldap/init-ldap.sh"
        "docker/certbot/entrypoint.sh"
        "docker/certbot/renew-certificates.sh"
        "docker/certbot/check-certificates.sh"
        "docker/certbot/hook-post-renew.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            log "✓ $script is executable"
        else
            error "✗ $script is not executable"
            return 1
        fi
    done
    
    return 0
}

# Test Dockerfile syntax
test_dockerfile_syntax() {
    log "Testing Dockerfile syntax..."
    
    # Test OpenLDAP Dockerfile
    if docker build -t test-openldap-syntax -f docker/openldap/Dockerfile docker/openldap/ >/dev/null 2>&1; then
        log "✓ OpenLDAP Dockerfile syntax is valid"
        docker rmi test-openldap-syntax >/dev/null 2>&1 || true
    else
        error "✗ OpenLDAP Dockerfile syntax error"
        return 1
    fi
    
    # Test Certbot Dockerfile
    if docker build -t test-certbot-syntax -f docker/certbot/Dockerfile docker/certbot/ >/dev/null 2>&1; then
        log "✓ Certbot Dockerfile syntax is valid"
        docker rmi test-certbot-syntax >/dev/null 2>&1 || true
    else
        error "✗ Certbot Dockerfile syntax error"
        return 1
    fi
    
    return 0
}

# Clean up test resources
cleanup() {
    log "Cleaning up test resources..."
    
    # Remove test containers and images
    docker-compose down >/dev/null 2>&1 || true
    docker rmi ldap-openldap:latest ldap-certbot:latest >/dev/null 2>&1 || true
    docker system prune -f >/dev/null 2>&1 || true
    
    log "Cleanup completed"
}

# Main test function
main() {
    echo "Docker Build Test Suite"
    echo "======================"
    
    local tests_passed=0
    local tests_failed=0
    local total_tests=6
    
    # Run tests
    if test_prerequisites; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_environment; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_scripts; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_dockerfile_syntax; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_docker_build; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_container_startup; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Display results
    echo
    echo "================="
    echo "Test Results:"
    echo "Passed: $tests_passed/$total_tests"
    echo "Failed: $tests_failed/$total_tests"
    echo "================="
    
    if [ $tests_failed -eq 0 ]; then
        log "All Docker build tests passed! 🎉"
        echo
        echo "Your Docker setup is ready. You can now run:"
        echo "  make init     # Complete deployment"
        echo "  make build    # Build images only"
        echo "  make deploy   # Deploy services"
    else
        error "Some Docker build tests failed!"
        echo
        echo "Please fix the issues above before proceeding."
    fi
    
    # Cleanup
    cleanup
    
    # Exit with appropriate code
    exit $tests_failed
}

# Run main function
main "$@"