# LDAP Authentication Server

Simple LDAP server with test users for authentication testing.

## What This Is

- **LDAP server** with TLS support (LDAPS on port 636)
- **Standard LDAP attributes** for user authentication
- **Microsoft AD compatibility** (optional)
- **5 test users** with different roles and departments

## Quick Start

```bash
# 1. Create environment configuration
make env
# Edit .env with your domain and passwords

# 2. Deploy LDAP server with certificates
make init

# 3. Create test users
make setup-users

# 4. Server is ready for LDAP queries
```

## Test Users

| Username | Password | Department | Role | Use Case |
|----------|----------|------------|------|----------|
| test-user-01 | TestPass123! | IT Department | Full-Time | Standard employee |
| test-user-02 | GuestPass789! | External | Temporary | Guest access |
| test-user-03 | AdminPass456! | IT Operations | Full-Time | Administrator |
| test-user-04 | ContractorPass321! | Professional Services | Contractor | External contractor |
| test-user-05 | VipPass654! | Executive Management | Executive | VIP user |

## LDAP Attributes

Each user includes **standard LDAP attributes**:

### Core Attributes
- `uid` - Primary username
- `cn` - Common name  
- `displayName` - User's display name
- `mail` - Email address
- `telephoneNumber` - Phone number
- `department` - Department/organizational unit
- `employeeType` - Employee type (Full-Time, Contractor, etc.)

### Microsoft AD Compatibility (Optional)
For systems expecting Active Directory attributes:
```bash
./scripts/add-msad-attributes.sh  # Adds sAMAccountName, userPrincipalName
```

## Available Commands

```bash
# Setup
make env           # Create .env file
make init          # Complete setup (certificates + deployment)

# Deployment  
make deploy        # Start LDAP service
make stop          # Stop LDAP service
make logs          # Show service logs
make clean         # Clean up containers and volumes

# Certificate Management
make copy-certs    # Copy certificates from external certbot
make build-tls     # Build OpenLDAP with TLS certificates

# User Management  
make setup-users   # Create test users (run after make init)

# Maintenance
make backup        # Export LDAP data to LDIF file
```

## LDAP Server Configuration

### Connection Settings
- **LDAP Server**: `ldap.yourdomain.com`
- **Port**: 636 (LDAPS recommended) or 389 (LDAP)
- **Base DN**: `dc=yourdomain,dc=com` (auto-generated from LDAP_DOMAIN)
- **Bind DN**: `cn=admin,dc=yourdomain,dc=com`
- **Bind Password**: Your LDAP_ADMIN_PASSWORD

### User Search Filters
```bash
# Primary username lookup (most common)
(uid=%username%)

# Alternative lookups
(cn=%username%)
(|(uid=%username%)(cn=%username%))

# Microsoft AD compatible (if AD attributes enabled)
(|(sAMAccountName=%username%)(userPrincipalName=%username%@yourdomain.com))
```

## Certificate Requirements

This project uses **automatic certificate management**:

1. **Certificate acquisition**: Handled automatically during `make init`
2. **TLS support**: LDAPS on port 636 with Let's Encrypt certificates
3. **Certificate renewal**: Automatic renewal via integrated certificate management

## Testing LDAP Server

### Manual LDAP Queries
```bash
# Test LDAP connection (replace yourdomain.com with your LDAP_DOMAIN)
ldapsearch -x -H ldap://localhost:389 -b "dc=yourdomain,dc=com"

# Test LDAPS connection  
ldapsearch -x -H ldaps://localhost:636 -b "dc=yourdomain,dc=com"

# Test user authentication
ldapsearch -x -H ldap://localhost:389 \
  -D "uid=test-user-01,ou=users,dc=yourdomain,dc=com" \
  -w "TestPass123!" -b "" -s base

# Search for a specific user
ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=yourdomain,dc=com" \
  -w "your-admin-password" \
  -b "ou=users,dc=yourdomain,dc=com" \
  "(uid=test-user-01)"
```

## Troubleshooting

### Common Issues
- **"Certificate acquisition failed"**: Check domain DNS configuration and firewall settings
- **"Authentication failed"**: Run `make setup-users` to create test users with correct passwords
- **"No such object" errors**: Use `make clean && make init && make setup-users` for fresh setup
- **"TLS connection failed"**: Restart with `make clean && make init` to refresh certificates

### Persistent Volume Issues
If users authenticate inconsistently, old Docker volumes may contain stale data:
```bash
make clean          # Removes old volumes completely
make init           # Fresh LDAP server deployment  
make setup-users    # Create users with current .env passwords
```

### Logs and Debugging
```bash
make logs                    # View LDAP service logs
docker compose ps            # Check container status
```

## Project Structure

```
ldap/
├── docker/
│   └── Dockerfile-tls        # OpenLDAP with TLS support
├── ldifs/
│   ├── 01-organizational-units.ldif  # Organizational units (ou=users, ou=groups)
│   ├── 02-users.ldif         # Test users (without passwords)
│   ├── 03-groups.ldif        # User groups
│   ├── 05-msad-compat.ldif   # Microsoft AD compatibility
│   └── 06-users-with-msad.ldif  # AD attributes for users
├── scripts/
│   ├── setup-users.sh        # Create test users with passwords
│   ├── copy-certs-for-build.sh  # Certificate management
│   └── backup-ldap.sh        # Simple LDIF export
├── docker-compose.yml        # Service definition
├── Makefile                 # Build commands
└── .env.example             # Environment template
```

## Security Notes

- **Test environment only** - Not hardened for production use
- **Default passwords** - Change all passwords in .env for real testing
- **Certificate management** - Uses Let's Encrypt staging by default
- **Network access** - Ports 389/636 exposed for LDAP access

---

This LDAP server provides a simple enterprise solution with standard LDAP attributes and 802.1X standards, with optional Microsoft AD compatibility.