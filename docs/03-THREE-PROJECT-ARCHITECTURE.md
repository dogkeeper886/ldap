# Three-Project Architecture Documentation

## Overview

This repository now implements a **three-project architecture** that separates certificate management from service deployment:

1. **`certbot/`** - Standalone multi-domain certificate management
2. **`ldap/`** - LDAP authentication server (modified to use external certbot)  
3. **`freeradius/`** - FreeRADIUS server with TLS support

## Architecture Benefits

✅ **Port Conflict Resolution** - Single certbot on port 80 serves all projects  
✅ **Independent Deployment** - Each service can be deployed/managed separately  
✅ **Shared Certificate Lifecycle** - Multi-domain SAN certificates distributed automatically  
✅ **Scalable Pattern** - Easy to add new services requiring TLS certificates  

## Project Structure

```
/home/jack/Documents/ldap/
├── certbot/                    # Standalone certificate management
│   ├── docker-compose.yml     # Multi-domain certbot service
│   ├── scripts/
│   │   └── test-certificates.sh      # Certificate validation
│   └── Makefile               # Certificate management commands
├── ldap/                      # Modified LDAP project (no certbot)
│   ├── docker-compose.yml     # OpenLDAP service only
│   ├── scripts/copy-certs-for-build.sh  # External certbot integration
│   └── Makefile               # LDAP deployment commands
└── freeradius/                # New FreeRADIUS project
    ├── docker-compose.yml     # FreeRADIUS service
    ├── docker/freeradius/     # FreeRADIUS configuration & TLS setup
    ├── scripts/               # FreeRADIUS deployment scripts
    └── Makefile               # RADIUS deployment commands
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
make copy-certs && make build-tls && make deploy
```

### 4. Deploy FreeRADIUS Service
```bash
cd freeradius
make copy-certs && make build-tls && make deploy
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

## Testing & Validation

### Test Certificate Acquisition
```bash
cd certbot
make test  # Validate certificates
```

### Test LDAP Authentication
```bash
cd ldap
make test  # Test LDAP authentication
make test-tls  # Test LDAPS connections
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
   cd ldap && make copy-certs && make build-tls && make restart
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
- **"TLS handshake failed"**: Check certificate domain matches LDAP_DOMAIN

### FreeRADIUS Issues
- **"Authentication failed"**: Verify user passwords in .env file
- **"TLS listener not active"**: Check certificate files in build context
- **"Configuration invalid"**: `cd freeradius && make config-test`

## Implementation Status

✅ **Phase 1**: Standalone Certbot Project (COMPLETED)  
✅ **Phase 2**: LDAP Project Separation (COMPLETED)  
✅ **Phase 3**: FreeRADIUS Project Creation (COMPLETED)  

**Total Implementation Time**: ~8 hours as planned in brainstorming session

## Next Steps

1. **Production Deployment**: Configure real domains and production Let's Encrypt
2. **WiFi Integration**: Connect to actual WiFi access points
3. **Monitoring**: Add certificate expiration monitoring
4. **Backup**: Implement certificate and configuration backup procedures

---

This three-project architecture successfully resolves the original port 80 conflict while providing independent, scalable certificate management for multiple authentication services.