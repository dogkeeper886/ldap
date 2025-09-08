#!/bin/bash
# Certificate Health Check Script
# Purpose: Health check for certificate status and validity

set -euo pipefail

# Exit codes for health check
HEALTH_OK=0
HEALTH_WARNING=1
HEALTH_CRITICAL=2

# Check if certificates exist
check_certificate_exists() {
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
    local key_file="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
    local chain_file="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
    
    if [ -f "$cert_file" ] && [ -f "$key_file" ] && [ -f "$chain_file" ]; then
        return 0
    else
        echo "CRITICAL: Certificate files missing for $DOMAIN"
        return 2
    fi
}

# Check certificate validity
check_certificate_validity() {
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
    
    if [ ! -f "$cert_file" ]; then
        echo "CRITICAL: Certificate file not found"
        return 2
    fi
    
    # Check if certificate is valid
    if ! openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1; then
        echo "CRITICAL: Certificate file is corrupted or invalid"
        return 2
    fi
    
    # Check expiry
    if openssl x509 -in "$cert_file" -noout -checkend 604800 >/dev/null 2>&1; then
        # Valid for at least 7 days
        if openssl x509 -in "$cert_file" -noout -checkend 2592000 >/dev/null 2>&1; then
            # Valid for at least 30 days
            echo "OK: Certificate is valid"
            return 0
        else
            echo "WARNING: Certificate expires within 30 days"
            return 1
        fi
    else
        echo "CRITICAL: Certificate expires within 7 days or is already expired"
        return 2
    fi
}

# Check certificate domain
check_certificate_domain() {
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
    
    if [ ! -f "$cert_file" ]; then
        echo "CRITICAL: Certificate file not found"
        return 2
    fi
    
    # Check if domain is in certificate
    if openssl x509 -in "$cert_file" -noout -text | grep -q "$DOMAIN"; then
        echo "OK: Certificate domain matches"
        return 0
    else
        echo "CRITICAL: Certificate domain mismatch"
        return 2
    fi
}

# Check Let's Encrypt service connectivity
check_letsencrypt_connectivity() {
    # Try to connect to Let's Encrypt servers
    if curl -s --connect-timeout 10 https://acme-v02.api.letsencrypt.org/directory >/dev/null 2>&1; then
        echo "OK: Let's Encrypt service accessible"
        return 0
    else
        echo "WARNING: Cannot connect to Let's Encrypt service"
        return 1
    fi
}

# Check disk space
check_disk_space() {
    local disk_usage
    disk_usage=$(df /etc/letsencrypt | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt 95 ]; then
        echo "CRITICAL: Disk usage critical: ${disk_usage}%"
        return 2
    elif [ "$disk_usage" -gt 85 ]; then
        echo "WARNING: Disk usage high: ${disk_usage}%"
        return 1
    else
        echo "OK: Disk usage normal: ${disk_usage}%"
        return 0
    fi
}

# Check certbot process
check_certbot_process() {
    # This is a health check, so we're checking if certbot can run
    if command -v certbot >/dev/null 2>&1; then
        echo "OK: Certbot command available"
        return 0
    else
        echo "CRITICAL: Certbot command not found"
        return 2
    fi
}

# Show certificate information
show_certificate_info() {
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
    
    if [ -f "$cert_file" ]; then
        echo "Certificate Information:"
        echo "  Domain: $DOMAIN"
        echo "  File: $cert_file"
        
        local subject
        local issuer
        local expiry_date
        local days_left
        
        subject=$(openssl x509 -in "$cert_file" -noout -subject | sed 's/subject=//' || echo "Unknown")
        issuer=$(openssl x509 -in "$cert_file" -noout -issuer | sed 's/issuer=//' || echo "Unknown")
        expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2 || echo "Unknown")
        
        echo "  Subject: $subject"
        echo "  Issuer: $issuer"
        echo "  Expires: $expiry_date"
        
        # Calculate days left
        if [ "$expiry_date" != "Unknown" ]; then
            local expiry_epoch
            local current_epoch
            expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
            current_epoch=$(date +%s)
            days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
            echo "  Days remaining: $days_left"
        fi
    else
        echo "Certificate Information: No certificate found for $DOMAIN"
    fi
}

# Main health check function
main() {
    local overall_status=$HEALTH_OK
    local checks_run=0
    local checks_failed=0
    
    echo "Certbot Health Check for domain: ${DOMAIN}"
    echo "========================================"
    
    # Run all health checks
    local check_results=()
    
    # Certificate existence
    ((checks_run++))
    if ! result=$(check_certificate_exists 2>&1); then
        check_results+=("$result")
        overall_status=$HEALTH_CRITICAL
        ((checks_failed++))
    else
        check_results+=("OK: Certificate files exist")
    fi
    
    # Certificate validity
    ((checks_run++))
    if ! result=$(check_certificate_validity 2>&1); then
        check_results+=("$result")
        if [ $? -eq 2 ] && [ $overall_status -lt $HEALTH_CRITICAL ]; then
            overall_status=$HEALTH_CRITICAL
        elif [ $? -eq 1 ] && [ $overall_status -lt $HEALTH_WARNING ]; then
            overall_status=$HEALTH_WARNING
        fi
        ((checks_failed++))
    else
        check_results+=("$result")
    fi
    
    # Certificate domain
    ((checks_run++))
    if ! result=$(check_certificate_domain 2>&1); then
        check_results+=("$result")
        if [ $overall_status -lt $HEALTH_CRITICAL ]; then
            overall_status=$HEALTH_CRITICAL
        fi
        ((checks_failed++))
    else
        check_results+=("$result")
    fi
    
    # Let's Encrypt connectivity
    ((checks_run++))
    if ! result=$(check_letsencrypt_connectivity 2>&1); then
        check_results+=("$result")
        if [ $overall_status -lt $HEALTH_WARNING ]; then
            overall_status=$HEALTH_WARNING
        fi
        ((checks_failed++))
    else
        check_results+=("$result")
    fi
    
    # Disk space
    ((checks_run++))
    if ! result=$(check_disk_space 2>&1); then
        check_results+=("$result")
        if [ $? -eq 2 ] && [ $overall_status -lt $HEALTH_CRITICAL ]; then
            overall_status=$HEALTH_CRITICAL
        elif [ $? -eq 1 ] && [ $overall_status -lt $HEALTH_WARNING ]; then
            overall_status=$HEALTH_WARNING
        fi
        ((checks_failed++))
    else
        check_results+=("$result")
    fi
    
    # Certbot process
    ((checks_run++))
    if ! result=$(check_certbot_process 2>&1); then
        check_results+=("$result")
        if [ $overall_status -lt $HEALTH_CRITICAL ]; then
            overall_status=$HEALTH_CRITICAL
        fi
        ((checks_failed++))
    else
        check_results+=("$result")
    fi
    
    # Display results
    echo
    echo "Health Check Results:"
    for result in "${check_results[@]}"; do
        echo "  $result"
    done
    
    echo
    echo "Summary:"
    echo "  Checks run: $checks_run"
    echo "  Checks failed: $checks_failed"
    echo "  Overall status: $([ $overall_status -eq 0 ] && echo "HEALTHY" || [ $overall_status -eq 1 ] && echo "WARNING" || echo "CRITICAL")"
    
    # Show certificate info if verbose or if there are issues
    if [ "${1:-}" = "--verbose" ] || [ $overall_status -ne $HEALTH_OK ]; then
        echo
        show_certificate_info
    fi
    
    # Update health status file
    cat > /tmp/certbot-health.txt << EOF
Certbot Health Status
Last Check: $(date)
Domain: ${DOMAIN}
Status: $([ $overall_status -eq 0 ] && echo "HEALTHY" || [ $overall_status -eq 1 ] && echo "WARNING" || echo "CRITICAL")
Checks Run: $checks_run
Checks Failed: $checks_failed
EOF
    
    exit $overall_status
}

# Run main function
main "$@"