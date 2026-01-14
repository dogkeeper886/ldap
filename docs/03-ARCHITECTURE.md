# Five-Project Architecture Documentation

## Overview

This repository implements a **five-project architecture** for enterprise authentication testing:

1. **`certbot/`** - Standalone multi-domain certificate management
2. **`ldap/`** - OpenLDAP authentication server with TLS support
3. **`freeradius/`** - FreeRADIUS server with EAP-TLS and SQL logging
4. **`keycloak/`** - SAML 2.0 Identity Provider with LDAP federation
5. **`mail/`** - Receive-only mail server for credential delivery

## Architecture Benefits

✅ **Port Conflict Resolution** - Single certbot on port 80 serves all projects  
✅ **Independent Deployment** - Each service can be deployed/managed separately  
✅ **Shared Certificate Lifecycle** - Multi-domain SAN certificates distributed automatically  
✅ **Scalable Pattern** - Easy to add new services requiring TLS certificates  

## Project Structure

```
ldap/
├── certbot/                    # Standalone certificate management
│   ├── docker-compose.yml      # Multi-domain certbot service
│   ├── scripts/                # Certificate validation scripts
│   └── Makefile                # Certificate management commands
├── ldap/                       # OpenLDAP authentication server
│   ├── docker-compose.yml      # OpenLDAP service
│   ├── scripts/                # User setup and cert scripts
│   └── Makefile                # LDAP deployment commands
├── freeradius/                 # FreeRADIUS with SQL logging
│   ├── docker-compose.yml      # FreeRADIUS + PostgreSQL services
│   ├── docker/freeradius/      # FreeRADIUS configuration & TLS
│   ├── sql/                    # PostgreSQL schema
│   ├── docs/                   # RADIUS-specific documentation
│   └── Makefile                # RADIUS deployment commands
├── keycloak/                   # SAML 2.0 Identity Provider
│   ├── docker-compose.yml      # Keycloak service
│   ├── config/                 # Realm configuration
│   ├── scripts/                # LDAP federation setup
│   └── Makefile                # Keycloak deployment commands
├── mail/                       # Receive-only mail server
│   ├── docker-compose.yml      # Postfix/Dovecot service
│   ├── scripts/                # Mail management scripts
│   └── Makefile                # Mail server commands
└── docs/                       # Project-wide documentation
    ├── 01-brainstorming-session-results.md
    ├── 02-PRD.md
    └── 03-ARCHITECTURE.md      # This file
```

## Multi-Domain Certificate Strategy

The standalone certbot acquires a **SAN certificate** covering both domains:
- `ldap.example.com` (LDAP service)
- `radius.example.com` (FreeRADIUS service)

Certificate distribution uses **Docker CP** pattern to avoid permission issues:
1. Certbot container acquires certificates
2. Scripts copy certificates from container to project build contexts
3. Services build with certificates included at build-time

## Deployment Sequence

### 1. Start Standalone Certbot
```bash
cd certbot
make env          # Configure domains and email
make deploy       # Start certbot service
```

### 2. Certificates Available
```bash
# Certificates are available in the running certbot container
# Each project copies certificates as needed using docker cp
```

### 3. Deploy LDAP Service
```bash
cd ldap
make init          # Deploy LDAP server with certificates
make setup-users   # Create test users with passwords
```

### 4. Deploy FreeRADIUS Service
```bash
cd freeradius
make copy-certs && make build-tls && make deploy
```

### 5. Deploy Keycloak SAML IdP (optional)
```bash
cd keycloak
make init          # copy-certs → deploy → test → setup-realm
```

### 6. Deploy Mail Server (optional)
```bash
cd mail
make deploy        # Start receive-only mail server
```

## Environment Configuration

Each project has its own `.env` file:

### certbot/.env
```bash
LDAP_DOMAIN=ldap.example.com
RADIUS_DOMAIN=radius.example.com
LETSENCRYPT_EMAIL=admin@example.com
STAGING=true  # Use Let's Encrypt staging for testing
```

### ldap/.env
```bash
LDAP_DOMAIN=ldap.example.com
LDAP_ADMIN_PASSWORD=secure_admin_pass
# ... other LDAP settings
```

### freeradius/.env
```bash
RADIUS_DOMAIN=radius.example.com
RADIUS_SECRET=secure_radius_secret
TEST_USER_PASSWORD=testpass123
# ... other RADIUS settings
```

## Service Ports

| Service | Ports | Protocol | Purpose |
|---------|-------|----------|---------|
| Certbot | 80 | HTTP | Certificate acquisition (Let's Encrypt) |
| LDAP | 389, 636 | LDAP/LDAPS | Directory authentication |
| FreeRADIUS | 1812, 1813 | UDP | RADIUS Auth/Accounting |
| FreeRADIUS | 2083 | TCP/TLS | RADIUS over TLS (RadSec) |
| PostgreSQL | 5432 | TCP | RADIUS SQL logging (internal) |
| Keycloak | 8080, 8443 | HTTP/HTTPS | SAML IdP endpoints |
| Mail | 25, 587 | SMTP | Mail receiving |
| Mail | 993 | IMAPS | Mail retrieval |

## Testing & Validation

### Test Certificate Acquisition
```bash
cd certbot
make test  # Validate certificates
```

### Test LDAP Authentication
```bash
cd ldap
make setup-users   # Ensure test users are created first
# Test user authentication manually:
ldapsearch -x -H ldap://localhost:389 -D "uid=test-user-01,ou=users,dc=yourdomain,dc=com" -w "TestPass123!" -b "" -s base
```

### Test FreeRADIUS Authentication
```bash
cd freeradius
make test  # Test basic RADIUS auth
make test-users  # Test all configured users
make test-tls  # Test RadSec (RADIUS over TLS)
```

## Operational Commands

### Certificate Management
```bash
cd certbot
make status        # Check certbot status
make renew         # Force certificate renewal
```

### Service Management
```bash
# Each project supports:
make deploy        # Start service
make stop          # Stop service
make restart       # Restart service
make logs          # View logs
make status        # Check status
make clean         # Clean up containers
```

## Certificate Renewal Workflow

The standalone certbot handles automatic renewal:

1. **Automatic Renewal**: Certbot checks every 12 hours (configurable)
2. **Manual Renewal**: `cd certbot && make renew`
3. **Copy Updated Certificates**: Each project copies certificates as needed
4. **Rebuild Services**: Each service needs rebuild to pick up new certificates
   ```bash
   cd ldap && make clean && make init && make setup-users
   cd freeradius && make copy-certs && make build-tls && make restart
   ```

## FreeRADIUS Features

The FreeRADIUS project includes:

✅ **Multi-EAP Support**: EAP-TLS, EAP-TTLS, EAP-PEAP, EAP-MSCHAPv2  
✅ **TLS/RadSec**: RADIUS over TLS on port 2083  
✅ **Test Users**: Pre-configured users for validation  
✅ **WiFi AP Ready**: Compatible with enterprise WiFi access points  
✅ **Security Hardened**: Modern TLS ciphers and security settings  

### Test Users

| Username | Password | Role | IP Range |
|----------|----------|------|----------|
| test | testpass123 | Basic user | 192.168.100.x |
| guest | guestpass123 | Limited access | 192.168.200.x |
| admin | adminpass123 | Administrator | 192.168.10.x |
| contractor | contractorpass123 | Time-limited | 192.168.150.x |
| vip | vippass123 | Priority user | 192.168.50.x |

## Troubleshooting

### Certificate Issues
- **"Certbot container not running"**: `cd certbot && make deploy`
- **"Certificate not found"**: Check if certbot container is running, then each project should copy certificates
- **"Permission denied"**: Check certificate file permissions (644 for certs, 640 for keys)

### LDAP Issues
- **"External certbot required"**: Ensure standalone certbot is running first
- **"Authentication failed"**: Run `make setup-users` to create test users with correct passwords
- **"No such object" errors**: Use `make clean && make init && make setup-users` for fresh setup
- **"TLS handshake failed"**: Check certificate domain matches LDAP_DOMAIN
- **Intermittent login issues**: Old Docker volumes - use `make clean` before deployment

### FreeRADIUS Issues
- **"Authentication failed"**: Verify user passwords in .env file
- **"TLS listener not active"**: Check certificate files in build context
- **"Configuration invalid"**: `cd freeradius && make config-test`

## Implementation Status

✅ **Phase 1**: Standalone Certbot Project
✅ **Phase 2**: LDAP Project Separation
✅ **Phase 3**: FreeRADIUS Project with SQL Logging
✅ **Phase 4**: Keycloak SAML IdP
✅ **Phase 5**: Mail Server
✅ **Phase 6**: EAP-TLS Client Certificate Support

## Development Sequence

1. Certbot + LDAP + basic RADIUS (initial setup)
2. RADIUS SQL logging with PostgreSQL
3. Keycloak SAML IdP with LDAP federation
4. Receive-only mail server
5. EAP-TLS client certificate authentication

---

This five-project architecture provides a complete enterprise authentication testing platform with LDAP, RADIUS, SAML, and mail services sharing a common certificate infrastructure.