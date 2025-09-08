#!/bin/bash
# OpenLDAP Health Check Script
# Purpose: Verify LDAP service is running and responsive

set -euo pipefail

# Exit codes
HEALTH_OK=0
HEALTH_WARNING=1
HEALTH_CRITICAL=2

# Logging function
log() {
    echo "[Health][$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[Health][$(date +'%H:%M:%S')] ERROR: $1" >&2
}

# Check if LDAP service is running
check_ldap_process() {
    if pgrep -f slapd >/dev/null; then
        return 0
    else
        error "slapd process not running"
        return 1
    fi
}

# Check LDAP connectivity
check_ldap_connectivity() {
    # Test basic LDAP connection
    if ldapsearch -x -H ldap://localhost -b "" -s base >/dev/null 2>&1; then
        return 0
    else
        error "LDAP connection failed"
        return 1
    fi
}

# Check LDAPS connectivity (if TLS is enabled)
check_ldaps_connectivity() {
    if [ "${LDAP_TLS:-false}" = "true" ]; then
        # For development/testing, don't verify certificates
        if [ "${ENVIRONMENT:-development}" = "development" ]; then
            if ldapsearch -x -H ldaps://localhost:636 -b "" -s base >/dev/null 2>&1; then
                return 0
            else
                error "LDAPS connection failed"
                return 1
            fi
        else
            # In production, verify certificates
            if echo "Q" | openssl s_client -connect localhost:636 -verify_return_error >/dev/null 2>&1; then
                return 0
            else
                error "LDAPS connection or certificate validation failed"
                return 1
            fi
        fi
    else
        # TLS not enabled, skip check
        return 0
    fi
}

# Check database accessibility
check_database() {
    local base_dn="dc=${LDAP_DOMAIN//./,dc=}"
    
    # Try to search the base DN
    if ldapsearch -x -H ldap://localhost -b "$base_dn" -s base >/dev/null 2>&1; then
        return 0
    else
        error "Database query failed"
        return 1
    fi
}

# Check certificate validity (if TLS enabled)
check_certificates() {
    if [ "${LDAP_TLS:-false}" = "true" ]; then
        local cert_file="/container/service/slapd/assets/certs/cert.pem"
        
        if [ -f "$cert_file" ]; then
            # Check if certificate is valid and not expiring soon
            if openssl x509 -in "$cert_file" -noout -checkend 86400 >/dev/null 2>&1; then
                return 0
            else
                error "Certificate is invalid or expiring within 24 hours"
                return 1
            fi
        else
            error "Certificate file not found"
            return 1
        fi
    else
        # TLS not enabled, skip check
        return 0
    fi
}

# Check disk space
check_disk_space() {
    local disk_usage
    disk_usage=$(df /var/lib/ldap | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt 95 ]; then
        error "Critical disk usage: ${disk_usage}%"
        return 2
    elif [ "$disk_usage" -gt 85 ]; then
        error "High disk usage: ${disk_usage}%"
        return 1
    else
        return 0
    fi
}

# Check memory usage
check_memory() {
    local mem_available
    mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    local mem_available_mb=$((mem_available / 1024))
    
    if [ "$mem_available_mb" -lt 50 ]; then
        error "Critical memory: ${mem_available_mb}MB available"
        return 2
    elif [ "$mem_available_mb" -lt 100 ]; then
        error "Low memory: ${mem_available_mb}MB available"
        return 1
    else
        return 0
    fi
}

# Main health check function
main() {
    local exit_code=$HEALTH_OK
    local checks_failed=0
    
    log "Starting health check..."
    
    # Critical checks
    if ! check_ldap_process; then
        exit_code=$HEALTH_CRITICAL
        ((checks_failed++))
    fi
    
    if ! check_ldap_connectivity; then
        exit_code=$HEALTH_CRITICAL
        ((checks_failed++))
    fi
    
    if ! check_database; then
        exit_code=$HEALTH_CRITICAL
        ((checks_failed++))
    fi
    
    # Warning checks
    if ! check_ldaps_connectivity; then
        if [ $exit_code -eq $HEALTH_OK ]; then
            exit_code=$HEALTH_WARNING
        fi
        ((checks_failed++))
    fi
    
    if ! check_certificates; then
        if [ $exit_code -eq $HEALTH_OK ]; then
            exit_code=$HEALTH_WARNING
        fi
        ((checks_failed++))
    fi
    
    # Resource checks
    local disk_check_result
    local memory_check_result
    
    check_disk_space
    disk_check_result=$?
    
    check_memory
    memory_check_result=$?
    
    # Update exit code based on resource checks
    if [ $disk_check_result -eq 2 ] || [ $memory_check_result -eq 2 ]; then
        exit_code=$HEALTH_CRITICAL
        ((checks_failed++))
    elif [ $disk_check_result -eq 1 ] || [ $memory_check_result -eq 1 ]; then
        if [ $exit_code -eq $HEALTH_OK ]; then
            exit_code=$HEALTH_WARNING
        fi
        ((checks_failed++))
    fi
    
    # Log results
    if [ $exit_code -eq $HEALTH_OK ]; then
        log "Health check passed - all systems operational"
    elif [ $exit_code -eq $HEALTH_WARNING ]; then
        log "Health check warning - $checks_failed checks failed"
    else
        log "Health check failed - $checks_failed critical issues"
    fi
    
    # Update health status file
    cat > /opt/ldap-health/status.txt << EOF
OpenLDAP Health Status
Last Check: $(date)
Status: $([ $exit_code -eq 0 ] && echo "HEALTHY" || [ $exit_code -eq 1 ] && echo "WARNING" || echo "CRITICAL")
Checks Failed: $checks_failed
Domain: ${LDAP_DOMAIN:-not-set}
TLS: ${LDAP_TLS:-false}
Environment: ${ENVIRONMENT:-development}
EOF
    
    exit $exit_code
}

# Run main function
main "$@"