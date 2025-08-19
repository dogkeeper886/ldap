# LDAP Server for WiFi Authentication Testing

A production-ready LDAP server for testing WiFi authentication with RUCKUS One Access Points. Get secure LDAP directory services running in minutes with automated TLS certificates and pre-configured test users.

## 🚀 Quick Start

### What You Need
- Domain name (e.g., `ldap.yourdomain.com`)
- GCP VM or any Linux server with Docker
- 15 minutes for setup

### 1. Get It Running
```bash
# Clone the project
git clone https://github.com/dogkeeper886/ldap.git
cd ldap

# Create configuration
make env
# Edit .env with your domain and email

# Deploy everything
make init
```

### 2. Test It Works
```bash
# Check health
make health

# Test authentication
make test-auth

# View all users
make view-ldap
```

### 3. Connect Your WiFi
Configure your RUCKUS One Access Point:
- **Server**: `ldap.yourdomain.com`
- **Port**: `636` (LDAPS)
- **Base DN**: `dc=example,dc=com`
- **Bind DN**: `cn=admin,dc=example,dc=com`

**Test Users Ready to Use:**
- `test-user-01` (IT Department) - Full access
- `test-user-02` (Guest) - Limited access  
- `test-user-03` (Admin) - Full privileges
- `test-user-04` (Contractor) - Standard access
- `test-user-05` (Executive) - VIP access

## 📋 Common Operations

### Daily Operations
```bash
# Check system health
make health

# View logs
make logs

# Create backup
make backup

# Restart services
make restart
```

### User Management
```bash
# Reset test users
make setup-users

# View all LDAP data
make view-ldap

# Access LDAP container
make shell-ldap
```

### Certificate Management
```bash
# Check certificate status
make health-verbose

# Force certificate renewal
make force-renew-certs
```

## 🧪 Testing Examples

### Test User Authentication
```bash
# Test specific user
ldapsearch -x -H ldaps://ldap.yourdomain.com:636 \
  -D "uid=test-user-01,ou=users,dc=example,dc=com" \
  -w "TestPass123!" \
  -b "" -s base
```

### Test Attribute Retrieval (RUCKUS Required)
```bash
# Get user attributes for access policies
ldapsearch -x -H ldaps://ldap.yourdomain.com:636 \
  -D "cn=admin,dc=example,dc=com" \
  -w "your_admin_password" \
  -b "uid=test-user-01,ou=users,dc=example,dc=com" \
  displayName mail telephoneNumber department
```

### Test TLS Security
```bash
# Verify certificate
openssl s_client -connect ldap.yourdomain.com:636

# Test TLS configuration
make test-tls
```

## 📡 RUCKUS One Integration

### Identity Provider Setup
1. **Add LDAP Server** in RUCKUS One dashboard
2. **Server Settings:**
   - Server: `ldap.yourdomain.com`
   - Port: `636` (LDAPS)
   - Security: SSL/TLS
   - Base DN: `dc=example,dc=com`
   - User Search Base: `ou=users,dc=example,dc=com`
   - User Search Filter: `(uid=%s)`

### Access Policy Examples
Create policies based on user attributes:

**IT Policy** (Full Access):
```
Condition: Custom Attribute 1 = "IT"
Access: Full network + admin privileges
```

**Guest Policy** (Limited):
```
Condition: Custom Attribute 1 = "Guest"  
Access: Internet only, 4 hours, 10 Mbps
```

**Executive Policy** (VIP):
```
Condition: Custom Attribute 1 = "Executive"
Access: Premium network, unlimited, high priority
```

### Attribute Mapping
| RUCKUS Field | LDAP Attribute | Example Value |
|--------------|----------------|---------------|
| Display Name | displayName | "Test User One" |
| Email | mail | "test.user01@example.com" |
| Phone | telephoneNumber | "+1-555-0101" |
| Custom Attribute 1 | department | "IT" |

## 🔧 Configuration

### Environment File (.env)
```bash
# Your Settings
LDAP_DOMAIN=ldap.yourdomain.com
LETSENCRYPT_EMAIL=admin@yourdomain.com
LDAP_ADMIN_PASSWORD=your_secure_admin_password

# Test User Passwords (change these!)
TEST_USER_PASSWORD=TestPass123!
GUEST_USER_PASSWORD=GuestPass789!
ADMIN_USER_PASSWORD=AdminPass456!
CONTRACTOR_PASSWORD=ContractorPass321!
VIP_PASSWORD=VipPass654!

# Environment
ENVIRONMENT=production
```

### Test User Details
| Username | Password | Department | Access Level | Use Case |
|----------|----------|------------|--------------|----------|
| test-user-01 | TestPass123! | IT | Standard | Regular employee |
| test-user-02 | GuestPass789! | Guest | Limited | Guest access |
| test-user-03 | AdminPass456! | IT | Admin | Administrative |
| test-user-04 | ContractorPass321! | External | Standard | Contractor |
| test-user-05 | VipPass654! | Executive | Premium | VIP/Executive |

## 🚨 Troubleshooting

### Common Issues

**Certificate Problems:**
```bash
# Check certificate status
make health-verbose

# Force renewal
make force-renew-certs

# Verify DNS
dig ldap.yourdomain.com
```

**Authentication Failures:**
```bash
# Test users exist
make view-ldap | grep test-user

# Reset users
make setup-users

# Check admin password
make test-auth
```

**Service Issues:**
```bash
# Check status
make status

# View logs
make logs

# Restart everything
make restart
```

### Getting Help
1. Check logs: `make logs`
2. Run health check: `make health-verbose` 
3. Run tests: `make test`
4. Check [DEPLOYMENT.md](DEPLOYMENT.md) for detailed setup
5. Open shell: `make shell-ldap`

## 📚 Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide
- **[docs/architecture.md](docs/architecture.md)** - System architecture
- **[docs/prd.md](docs/prd.md)** - Product requirements

---

## 🛠️ Development Guide

### Project Architecture
- **Docker Compose** orchestration
- **OpenLDAP 2.6.6** with MDB backend
- **Let's Encrypt** automated certificates
- **GCP deployment** ready

### Development Setup
```bash
# Development environment
make dev-setup

# Edit configuration files
# Note: Uses self-signed certs for local testing
```

### Project Structure
```
ldap/
├── docker-compose.yml      # Main orchestration
├── Makefile               # Common operations
├── DEPLOYMENT.md          # Deployment guide
├── config/               # LDAP & Certbot config
├── docker/               # Custom Docker images
├── ldifs/                # LDAP schema & users
├── scripts/              # Automation scripts
├── tests/                # Test framework
└── docs/                 # Architecture & PRD
```

### Available Commands
```bash
# Setup & Deployment
make init          # Complete setup
make init-certs    # Get certificates
make deploy        # Start services
make setup-users   # Create test users

# Operations  
make health        # Health checks
make logs          # View logs
make backup        # Create backup
make restart       # Restart services

# Testing
make test          # Run all tests
make test-auth     # Test authentication
make test-tls      # Test TLS config

# Development
make shell-ldap    # LDAP container shell
make clean         # Clean containers
make rebuild       # Rebuild images
```

### Adding Users
1. Edit `ldifs/02-users.ldif`
2. Add user entry with required attributes
3. Run `make setup-users`

### Customizing Attributes
1. Modify LDIF files for additional attributes
2. Update test scripts if needed  
3. Redeploy with `make restart`

### Security Features
- **TLS 1.2+ only** encryption
- **SSHA password** hashing
- **Let's Encrypt** trusted certificates  
- **Network-level** access control
- **No plain-text** credentials

### Contributing
1. Test changes thoroughly
2. Update documentation
3. Ensure all tests pass
4. Follow security best practices

---

**Ready to test WiFi authentication with RUCKUS One Access Points!**