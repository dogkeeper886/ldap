#!/bin/bash
# Script: backup-ldap.sh
# Purpose: Backup LDAP data and certificates
# Usage: ./backup-ldap.sh [backup_name]

set -euo pipefail
IFS=$'\n\t'

# Trap errors
trap 'echo "Error on line $LINENO"' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Load environment variables
load_environment() {
    if [ -f ".env" ]; then
        set -a  # Automatically export all variables
        # shellcheck source=../.env
        source .env
        set +a
    else
        warn ".env file not found, using defaults"
        LDAP_DOMAIN=${LDAP_DOMAIN:-"example.com"}
        LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-"admin"}
    fi
}

# Create backup directory
create_backup_dir() {
    local backup_name="${1:-backup-$(date +%Y%m%d-%H%M%S)}"
    local backup_dir="volumes/backups/$backup_name"
    
    mkdir -p "$backup_dir"
    echo "$backup_dir"
}

# Backup LDAP data using slapcat
backup_ldap_data() {
    local backup_dir="$1"
    
    log "Backing up LDAP data..."
    
    # Export LDAP database
    docker exec openldap slapcat -n 1 > "$backup_dir/ldap-data.ldif"
    
    # Export LDAP configuration
    docker exec openldap slapcat -n 0 > "$backup_dir/ldap-config.ldif"
    
    log "LDAP data backup completed"
}

# Backup certificates
backup_certificates() {
    local backup_dir="$1"
    
    log "Backing up certificates..."
    
    if [ -d "volumes/certificates" ]; then
        cp -r volumes/certificates "$backup_dir/"
        log "Certificates backup completed"
    else
        warn "Certificates directory not found, skipping"
    fi
}

# Backup configuration files
backup_config() {
    local backup_dir="$1"
    
    log "Backing up configuration files..."
    
    mkdir -p "$backup_dir/config"
    
    # Backup docker compose and environment
    cp docker compose.yml "$backup_dir/config/"
    cp .env "$backup_dir/config/" 2>/dev/null || warn ".env file not found"
    
    # Backup custom configurations
    if [ -d "config" ]; then
        cp -r config "$backup_dir/"
    fi
    
    # Backup LDIF files
    if [ -d "ldifs" ]; then
        cp -r ldifs "$backup_dir/"
    fi
    
    log "Configuration backup completed"
}

# Create backup metadata
create_metadata() {
    local backup_dir="$1"
    
    log "Creating backup metadata..."
    
    cat > "$backup_dir/backup-info.txt" << EOF
Backup Information
==================
Backup Date: $(date)
LDAP Domain: $LDAP_DOMAIN
Environment: ${ENVIRONMENT:-development}
Backup Type: Full backup (data + config + certificates)

Container Versions:
$(docker compose images)

Docker Compose Version:
$(docker compose --version)

LDAP Statistics:
$(docker exec openldap ldapsearch -x -H ldap://localhost -D "cn=admin,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" -w "$LDAP_ADMIN_PASSWORD" -b "ou=users,dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}" "objectClass=inetOrgPerson" dn | grep -c "dn:" || echo "Unable to count users")

Health Check Status:
$(./scripts/health-check.sh 2>/dev/null | tail -5 || echo "Health check failed")
EOF
    
    log "Metadata created"
}

# Compress backup
compress_backup() {
    local backup_dir="$1"
    local backup_name
    backup_name=$(basename "$backup_dir")
    
    log "Compressing backup..."
    
    cd "$(dirname "$backup_dir")"
    tar -czf "${backup_name}.tar.gz" "$backup_name"
    
    # Remove uncompressed directory
    rm -rf "$backup_name"
    
    log "Backup compressed to: volumes/backups/${backup_name}.tar.gz"
    
    # Show backup size
    local backup_size
    backup_size=$(du -h "${backup_name}.tar.gz" | cut -f1)
    log "Backup size: $backup_size"
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups..."
    
    local backup_dir="volumes/backups"
    local retention_days="${BACKUP_RETENTION_DAYS:-7}"
    
    if [ -d "$backup_dir" ]; then
        # Remove backups older than retention period
        find "$backup_dir" -name "backup-*.tar.gz" -type f -mtime +$retention_days -delete
        
        # Keep only the last 5 backups regardless of age
        ls -t "$backup_dir"/backup-*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f
        
        log "Old backups cleaned up (keeping last 5 and those newer than $retention_days days)"
    fi
}

# Verify backup
verify_backup() {
    local backup_file="$1"
    
    log "Verifying backup integrity..."
    
    # Test if tar file is valid
    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        log "✓ Backup integrity verified"
        
        # Show backup contents
        log "Backup contents:"
        tar -tzf "$backup_file" | head -10
        if [ "$(tar -tzf "$backup_file" | wc -l)" -gt 10 ]; then
            log "... and $(( $(tar -tzf "$backup_file" | wc -l) - 10 )) more files"
        fi
    else
        error "✗ Backup integrity check failed"
        return 1
    fi
}

# Display backup summary
display_summary() {
    local backup_file="$1"
    
    echo
    log "Backup completed successfully!"
    echo
    echo "=== Backup Summary ==="
    echo "Backup file: $backup_file"
    echo "Backup size: $(du -h "$backup_file" | cut -f1)"
    echo "Backup date: $(date)"
    echo
    echo "To restore this backup, use:"
    echo "  ./scripts/restore-ldap.sh $backup_file"
    echo
    echo "Available backups:"
    ls -la volumes/backups/*.tar.gz 2>/dev/null | tail -5 || echo "No backups found"
}

# Main function
main() {
    local backup_name="${1:-}"
    
    log "Starting LDAP backup..."
    
    # Check prerequisites
    command -v docker >/dev/null 2>&1 || { 
        error "Docker is required but not installed"
        exit 1
    }
    
    load_environment
    
    # Check if containers are running
    if ! docker compose ps openldap | grep -q "Up"; then
        warn "OpenLDAP container is not running - backup may be incomplete"
    fi
    
    # Create backup
    local backup_dir
    backup_dir=$(create_backup_dir "$backup_name")
    
    backup_ldap_data "$backup_dir"
    backup_certificates "$backup_dir"
    backup_config "$backup_dir"
    create_metadata "$backup_dir"
    
    # Compress and verify
    compress_backup "$backup_dir"
    
    local backup_file="${backup_dir}.tar.gz"
    verify_backup "$backup_file"
    
    # Cleanup old backups
    cleanup_old_backups
    
    display_summary "$backup_file"
    
    log "Backup process completed successfully!"
}

# Run main function
main "$@"