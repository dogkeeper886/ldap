#!/bin/bash
set -euo pipefail

BACKUP_FILE="ldap-backup-$(date +%Y%m%d-%H%M%S).ldif"
docker exec openldap slapcat -n 1 > "$BACKUP_FILE"
