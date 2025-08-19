# LDAP Server for WiFi Authentication Testing

A production-ready LDAP server deployment using Docker Compose for WiFi authentication testing with RUCKUS One Access Points. This implementation provides TLS-secured LDAP services with automated certificate management and comprehensive test user support.

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Domain name pointing to your server's IP address
- GCP VM with fixed IP (or similar cloud instance)
- Firewall ports 636 (LDAPS) and 80 (HTTP for certificate validation) open

### 1. Initial Setup
```bash
# Clone or download the project
cd ldap

# Create environment configuration
make env
# Edit .env file with your domain and email

# Complete setup (build images + certificates + deployment + users)
make init
```

### 2. Verify Installation
```bash
# Run health checks
make health

# Test all functionality
make test

# View service status
make status
```

## 📋 Project Structure

```
ldap/
├── docker-compose.yml          # Main orchestration file
├── .env.example               # Environment template
├── Makefile                   # Common operations
├── README.md                  # This file
│
├── docker/                    # Custom Docker images
│   ├── openldap/             # OpenLDAP custom image
│   │   ├── Dockerfile        # OpenLDAP Dockerfile
│   │   ├── entrypoint.sh     # Custom entrypoint script
│   │   ├── health-check.sh   # Container health check
│   │   └── init-ldap.sh      # LDAP initialization
│   └── certbot/              # Certbot custom image
│       ├── Dockerfile        # Certbot Dockerfile
│       ├── entrypoint.sh     # Custom entrypoint script
│       ├── renew-certificates.sh # Renewal script
│       ├── check-certificates.sh # Health check
│       └── hook-post-renew.sh    # Post-renewal actions
│
├── config/                    # Configuration files
│   ├── openldap/             # LDAP client configuration
│   └── certbot/              # Certificate management config
│
├── scripts/                   # Automation scripts
│   ├── init-certificates.sh  # Certificate initialization
│   ├── setup-users.sh        # User creation
│   ├── health-check.sh       # System health monitoring
│   └── backup-ldap.sh        # Backup operations
│
├── ldifs/                     # LDAP data definitions
│   ├── 01-base.ldif          # Directory structure
│   ├── 02-users.ldif         # Test user accounts
│   ├── 03-groups.ldif        # Group definitions
│   └── 04-acls.ldif          # Access control reference
│
├── tests/                     # Test scripts
│   ├── test-authentication.sh # Auth testing
│   ├── test-attributes.sh     # Attribute validation
│   └── test-tls.sh           # TLS configuration tests
│
└── volumes/                   # Docker volumes (created automatically)
    ├── ldap-data/            # LDAP database
    ├── certificates/         # TLS certificates
    └── backups/              # Backup files
```

## 🔧 Configuration

### Environment Variables (.env)
```bash
# Required Configuration
LDAP_DOMAIN=your-domain.com
LETSENCRYPT_EMAIL=admin@your-domain.com
LDAP_ADMIN_PASSWORD=your_secure_admin_password
LDAP_CONFIG_PASSWORD=your_secure_config_password

# Test User Passwords
TEST_USER_PASSWORD=TestPass123!
GUEST_USER_PASSWORD=GuestPass789!
ADMIN_USER_PASSWORD=AdminPass456!
CONTRACTOR_PASSWORD=ContractorPass321!
VIP_PASSWORD=VipPass654!

# Environment
ENVIRONMENT=production  # or development
```

### Test Users
The system creates 5 test users with different access profiles:

| Username | Department | Employee Type | Access Level | Use Case |
|----------|------------|---------------|--------------|----------|
| test-user-01 | IT | Full-Time | Standard | Regular employee |
| test-user-02 | Guest | Visitor | Limited | Guest access |
| test-user-03 | IT | Admin | Full | Administrative access |
| test-user-04 | External | Contractor | Standard | External contractor |
| test-user-05 | Executive | Full-Time | Premium | VIP/Executive access |

## 📡 RUCKUS One Integration

### LDAP Server Settings
- **Server**: `your-domain.com`
- **Port**: `636` (LDAPS)
- **Base DN**: `dc=example,dc=com`
- **Bind DN**: `cn=admin,dc=example,dc=com`
- **User Search Base**: `ou=users,dc=example,dc=com`
- **User Search Filter**: `(uid=%s)`

### Identity Mapping
Configure RUCKUS One Identity Provider with these attribute mappings:

| RUCKUS Field | LDAP Attribute | Purpose |
|--------------|----------------|---------|
| Display Name | displayName | User's full name |
| Email | mail | Email address |
| Phone | telephoneNumber | Phone number |
| Custom Attribute 1 | department | Access control (IT, Guest, External, Executive) |

### Access Policies
Use the `department` attribute for access control policies:
- **IT**: Full network access
- **Guest**: Limited/time-restricted access
- **External**: Standard contractor access
- **Executive**: Premium/VIP access

## 🛠️ Operations

### Daily Operations
```bash
# Check system health
make health

# View logs
make logs
make logs-follow  # real-time

# Create backup
make backup

# Update and rebuild services
make update

# Rebuild from scratch
make rebuild
```

### User Management
```bash
# Reset test users
make setup-users

# View LDAP contents
make view-ldap

# Access container shell
make shell-ldap
```

### Certificate Management
```bash
# Manual certificate renewal
make renew-certs

# Force renewal (testing)
make force-renew-certs

# Check certificate status
make health-verbose
```

### Troubleshooting
```bash
# Check container status
make status

# Run comprehensive tests
make test

# View detailed logs
make logs-ldap
make logs-certbot

# Restart services
make restart
```

## 🧪 Testing

### Test Authentication
```bash
# Test all users
make test-auth

# Test specific user manually
ldapsearch -x -H ldaps://your-domain.com:636 \
  -D "uid=test-user-01,ou=users,dc=example,dc=com" \
  -w "TestPass123!" \
  -b "" -s base
```

### Test Attributes
```bash
# Test RUCKUS required attributes
make test-attributes

# Manual attribute query
ldapsearch -x -H ldaps://your-domain.com:636 \
  -D "cn=admin,dc=example,dc=com" \
  -w "your_admin_password" \
  -b "uid=test-user-01,ou=users,dc=example,dc=com" \
  displayName mail telephoneNumber department
```

### Test TLS Configuration
```bash
# Test TLS security
make test-tls

# Manual TLS test
openssl s_client -connect your-domain.com:636
```

## 🔒 Security Features

### TLS Security
- **TLS 1.2+ only** (1.0 and 1.1 disabled)
- **Strong cipher suites** (AES-256, etc.)
- **Let's Encrypt certificates** with auto-renewal
- **LDAPS on port 636** (encrypted)

### Access Control
- **Password protection** with SSHA hashing
- **User isolation** (users can only access own data)
- **Admin-only** directory management
- **Network-level** firewall protection

### Data Protection
- **Encrypted communication** (TLS)
- **Secure password storage** (hashed)
- **Regular backups** with compression
- **No sensitive data** in logs

## 📦 Backup & Recovery

### Automatic Backups
Backups are created in `volumes/backups/` and include:
- LDAP database export
- Certificate files
- Configuration files
- System metadata

### Manual Backup
```bash
# Create backup
make backup

# List backups
ls -la volumes/backups/

# Restore from backup
make restore FILE=volumes/backups/backup-20231201-120000.tar.gz
```

### Disaster Recovery
```bash
# Restore latest backup automatically
make disaster-recovery
```

## 🚨 Monitoring & Alerting

### Health Monitoring
```bash
# Quick health check
make health

# Detailed health report
make health-verbose

# Check specific components
./scripts/health-check.sh
```

### Performance Monitoring
```bash
# Resource usage
make status

# Performance tests
make test-performance

# View metrics
docker stats
```

## 🔧 Development & Customization

### Development Setup
```bash
# Create development environment
make dev-setup

# Edit configuration as needed
# Note: Uses self-signed certificates for local testing
```

### Adding Users
1. Edit `ldifs/02-users.ldif`
2. Add user entry with required attributes
3. Run `make setup-users`

### Customizing Attributes
1. Modify LDIF files for additional attributes
2. Update test scripts if needed
3. Redeploy with `make restart`

## 📚 Technical Documentation

For detailed technical information, see:
- [docs/architecture.md](docs/architecture.md) - System architecture and design
- [docs/prd.md](docs/prd.md) - Product requirements document
- [docs/brainstorming-session-results.md](docs/brainstorming-session-results.md) - Project background

## 🆘 Troubleshooting

### Common Issues

**Certificate Problems**
```bash
# Check certificate status
make health-verbose

# Force certificate renewal
make force-renew-certs

# Verify DNS is pointing to server
dig your-domain.com
```

**Authentication Failures**
```bash
# Test user authentication
make test-auth

# Check user exists
make view-ldap | grep test-user-01

# Reset users
make setup-users
```

**Container Issues**
```bash
# Check container logs
make logs

# Restart services
make restart

# Full cleanup and redeploy
make clean
make deploy
```

**Performance Issues**
```bash
# Check resource usage
make status

# Run performance tests
make test-performance

# Check disk space
df -h
```

### Getting Help

1. **Check logs**: `make logs`
2. **Run health check**: `make health-verbose`
3. **Run tests**: `make test`
4. **Check documentation**: Review architecture.md and PRD
5. **Container debugging**: `make shell-ldap`

## 📈 Production Checklist

Before going to production:

- [ ] DNS properly configured
- [ ] Firewall rules set (ports 636, 80)
- [ ] Environment variables configured
- [ ] Admin passwords changed from defaults
- [ ] Certificates acquired and valid
- [ ] All tests passing
- [ ] Backup strategy in place
- [ ] Monitoring configured
- [ ] RUCKUS One integration tested

```bash
# Production readiness check
make prod-check
```

## 📜 License

This project is provided as-is for educational and testing purposes. Modify and distribute according to your organization's requirements.

## 🤝 Contributing

To contribute improvements:
1. Test changes thoroughly
2. Update documentation
3. Ensure all tests pass
4. Follow security best practices

---

**Note**: This LDAP server is designed for WiFi authentication testing. For production identity management, consider additional security hardening and integration with your organization's identity systems.