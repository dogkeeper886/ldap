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

# 2. Start external certbot (required for TLS certificates)
cd ../certbot && make deploy

# 3. Deploy LDAP server with certificates and test users
make init

# 4. Server is ready for LDAP queries
```

## Architecture

This LDAP server is part of a **three-project architecture**:
- `../certbot/` - Certificate management for TLS (port 80)  
- `../ldap/` - **This LDAP server** (ports 389, 636)
- `../freeradius/` - RADIUS server (separate project)

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
make init          # Complete setup (certificates + deployment + users)

# Deployment  
make deploy        # Start LDAP service
make stop          # Stop LDAP service
make logs          # Show service logs
make clean         # Clean up containers and volumes

# Certificate Management
make copy-certs    # Copy certificates from external certbot
make build-tls     # Build OpenLDAP with TLS certificates

# User Management  
make setup-users   # Create test users

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

This project requires **external certificate management**:

1. **Start certbot first**: `cd ../certbot && make deploy`
2. **Copy certificates**: Handled automatically by `make copy-certs`
3. **TLS support**: LDAPS on port 636 with Let's Encrypt certificates

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
- **"External certbot container not running"**: Start certbot first: `cd ../certbot && make deploy`
- **"Authentication failed"**: Check user passwords in .env file
- **"TLS connection failed"**: Verify certificates copied correctly: `make copy-certs && make build-tls`

### Logs and Debugging
```bash
make logs                    # View LDAP service logs
docker compose ps            # Check container status
```

## Project Structure

```
ldap/
├── docker/
│   ├── Dockerfile-tls        # OpenLDAP with TLS support
│   ├── entrypoint.sh         # Simplified startup script
│   ├── health-check.sh       # Basic LDAP connectivity check  
│   └── init-ldap.sh          # Initialize users and data
├── ldifs/
│   ├── 01-base.ldif          # Base directory structure
│   ├── 02-users.ldif         # Test users
│   ├── 03-groups.ldif        # User groups
│   └── 05-msad-compat.ldif   # Microsoft AD compatibility
├── scripts/
│   ├── setup-users.sh        # Create test users
│   ├── copy-certs-for-build.sh  # Certificate management
│   ├── add-msad-attributes.sh   # AD compatibility setup
│   └── backup-ldap.sh        # Simple LDIF export
├── docker-compose.yml        # Service definition
├── Makefile                 # Simplified build commands
└── .env.example             # Environment template
```

## Security Notes

- **Test environment only** - Not hardened for production use
- **Default passwords** - Change all passwords in .env for real testing
- **Certificate management** - Uses Let's Encrypt staging by default
- **Network access** - Ports 389/636 exposed for LDAP access

---

This LDAP server provides a simple enterprisewith standard LDAPattributes and 802.1X standardsoptional Microsoft AD compatibility.