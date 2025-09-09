# LDAP Authentication Server with Certificate Management

Complete LDAP server solution for WiFi authentication testing with automatic SSL/TLS certificate management.

## What This Is

- **Two-project architecture**: Certificate management + LDAP server
- **Automatic certificates**: Let's Encrypt SSL/TLS certificates with auto-renewal
- **LDAP server** with TLS support (LDAPS on port 636)
- **Standard LDAP attributes** for user authentication
- **Microsoft AD compatibility** (optional)
- **5 test users** with different roles and departments

## Project Structure

```
ldap/
├── certbot/              # Certificate management (port 80)
│   └── README.md         # Certificate management documentation
├── ldap/                 # LDAP server (ports 389, 636)
│   └── README.md         # LDAP server documentation
└── README.md             # This overview
```

## Quick Start

### Prerequisites
- Linux server with Docker and Docker Compose
- Domain name pointing to your server
- Ports 80, 389, and 636 available

### 1. Setup Certificate Management

```bash
cd certbot

# Create environment configuration
make env

# Edit .env with your domain and email
nano .env
# Set: DOMAINS=ldap.example.com
#      LETSENCRYPT_EMAIL=admin@example.com
#      STAGING=true (for testing)

# Deploy certificate service
make deploy
```

### 2. Setup LDAP Server

```bash
cd ../ldap

# Create environment configuration
make env

# Edit .env with your LDAP settings
nano .env
# Set: LDAP_DOMAIN=ldap.example.com
#      LDAP_ADMIN_PASSWORD=your-secure-password

# Deploy LDAP server with certificates
make init

# Create test users
make setup-users
```

### 3. Server Ready for Authentication

Your LDAP server is now ready with:
- **LDAPS**: Port 636 (secure, recommended)
- **LDAP**: Port 389 (unencrypted)
- **SSL certificates**: Automatically renewed
- **Test users**: 5 users with different roles

## Architecture

### Certificate Management (`certbot/`)
- **Purpose**: Provides SSL/TLS certificates for LDAP server
- **Technology**: Official certbot Docker image
- **Renewal**: Automatic every 12 hours
- **Domains**: Supports multiple domains with SAN certificates
- **Port**: 80 (HTTP challenge for Let's Encrypt)

### LDAP Server (`ldap/`)
- **Purpose**: Directory authentication server
- **Technology**: OpenLDAP with TLS support
- **Certificates**: Uses certificates from certbot service
- **Ports**: 389 (LDAP), 636 (LDAPS)
- **Users**: 5 pre-configured test users

### Certificate Distribution
1. Certbot acquires certificates and stores them in Docker volume
2. LDAP server copies certificates from certbot container during build
3. OpenLDAP uses certificates for TLS/SSL connections
4. Certificates renew automatically without manual intervention

## Test Users

| Username | Password | Department | Role | Use Case |
|----------|----------|------------|------|----------|
| test-user-01 | TestPass123! | IT Department | Full-Time | Standard employee |
| test-user-02 | GuestPass789! | External | Temporary | Guest access |
| test-user-03 | AdminPass456! | IT Operations | Full-Time | Administrator |
| test-user-04 | ContractorPass321! | Professional Services | Contractor | External contractor |
| test-user-05 | VipPass654! | Executive Management | Executive | VIP user |

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

## Microsoft AD Compatibility

For access points expecting Active Directory attributes:

```bash
cd ldap
./scripts/add-msad-attributes.sh
```

This adds:
- `sAMAccountName` - Windows-style usernames
- `userPrincipalName` - user@domain.com format
- `userAccountControl` - Account status
- `memberOf` - Group membership

## WiFi Access Point Configuration

### RUCKUS One
```
Server Type: LDAP/LDAPS
Server: your-domain.com
Port: 636 (LDAPS) or 389 (LDAP)
Base DN: dc=your,dc=domain,dc=com
Admin DN: cn=admin,dc=your,dc=domain,dc=com
Admin Password: [your admin password]
Search Filter: uid=%s
```

### Microsoft AD Compatible APs
```
Search Filter Options:
- Standard: (uid=%s)
- MS AD Style: (sAMAccountName=%s)
- UPN Style: (userPrincipalName=%s)
- Combined: (|(sAMAccountName=%s)(userPrincipalName=%s))
```

## Common Operations

### Certificate Management
```bash
cd certbot
make logs        # Check certificate service
make stop        # Stop certificate service
make clean       # Remove certificates and containers
```

### LDAP Server Management
```bash
cd ldap
make logs        # View LDAP server logs
make stop        # Stop LDAP server
make clean       # Clean containers and volumes
make backup      # Export LDAP data
```

### View LDAP Directory
```bash
cd ldap
make view-ldap   # Show all users and groups
```

## Testing Authentication

### Command Line Testing
```bash
# Test LDAPS connection (secure, recommended)
ldapwhoami -x -H ldaps://your-domain.com:636 \
  -D "uid=test-user-01,ou=users,dc=your,dc=domain,dc=com" \
  -w "TestPass123!"

# Test LDAP connection (unencrypted)
ldapwhoami -x -H ldap://your-domain.com:389 \
  -D "uid=test-user-01,ou=users,dc=your,dc=domain,dc=com" \
  -w "TestPass123!"
```

### WiFi Client Testing
1. Configure device for WPA2/WPA3 Enterprise
2. Choose EAP method (PEAP or EAP-TTLS)
3. Username: `test-user-01`
4. Password: `TestPass123!`
5. Accept certificate if prompted

## Troubleshooting

### Certificate Issues
```bash
cd certbot
make logs        # Check certificate acquisition
```

Common certificate problems:
- **Domain not pointing to server**: Verify DNS configuration
- **Port 80 blocked**: Ensure firewall allows HTTP traffic
- **Rate limits**: Use `STAGING=true` for testing

### LDAP Issues
```bash
cd ldap
make logs        # Check LDAP server logs
```

Common LDAP problems:
- **Authentication failed**: Run `make setup-users` to recreate users
- **TLS connection failed**: Restart with `make clean && make init`
- **No such object**: Use `make clean && make init && make setup-users`

### Port Conflicts
- **Certbot requires port 80** for Let's Encrypt HTTP challenge
- **LDAP uses ports 389, 636** for directory queries
- **Cannot run multiple certbot instances** on same server

## Security Notes

- **Test environment only** - Not hardened for production use
- **Default passwords** - Change all passwords in .env files
- **Certificate staging** - Uses Let's Encrypt staging by default
- **Network access** - Ports exposed for authentication testing
- **Automatic renewal** - Certificates renew 30 days before expiration

## Support

For component-specific documentation:
- **Certificate management**: See `certbot/README.md`
- **LDAP server**: See `ldap/README.md`

For issues and questions, open an issue on GitHub.

---

**Complete LDAP authentication solution with automatic certificate management** 🔒