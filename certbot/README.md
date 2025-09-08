# Standalone Certbot - Multi-Domain Certificate Management

A standalone Docker-based certificate management solution that provides automated Let's Encrypt SSL/TLS certificates for multiple domains and distributes them to other projects.

## 🚀 What It Does

This standalone certbot service:

- **Acquires SSL/TLS certificates** from Let's Encrypt for one or multiple domains
- **Resolves port conflicts** by running a single certbot instance on port 80
- **Handles renewals** automatically with configurable intervals
- **Manages permissions** correctly for certificate files
- **Supports staging and production** Let's Encrypt environments

## 🏗️ Architecture Benefits

✅ **Single Port 80 Usage** - Eliminates conflicts between multiple services  
✅ **Multi-Domain Support** - One certificate for multiple subdomains (SAN)  
✅ **Independent Deployment** - Standalone service with no external dependencies  
✅ **Permission Management** - Handles file permissions automatically  
✅ **Production Ready** - Supports both staging and production Let's Encrypt  

## 📁 Project Structure

```
certbot/
├── docker-compose.yml          # Certbot service configuration
├── .env.example               # Environment template
├── Makefile                   # Operation commands
├── docker/certbot/            # Custom certbot Docker image
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── renew-certificates.sh
│   ├── check-certificates.sh
│   └── ...
└── scripts/                   # Certificate management scripts
    └── test-certificates.sh
```

## 🛠️ Quick Start

### 1. Initial Setup

```bash
# Clone or navigate to the certbot directory
cd certbot

# Create environment configuration
make env

# Edit .env file with your domains and email
vim .env
```

### 2. Deploy Certbot Service

```bash
# Build and start the service
make deploy

# Check status
make status
```

### 3. Access Certificates

```bash
# Certificates are available in the running container
# Other projects can copy them using docker cp commands
docker cp standalone-certbot:/etc/letsencrypt/live/ldap.example.com/cert.pem ./cert.pem
```

## ⚙️ Configuration

### Environment Variables (.env)

```bash
# Domain Configuration - Three Options Available

# Option 1: Direct multi-domain specification (RECOMMENDED)
DOMAINS=ldap.example.com,radius.example.com,web.example.com

# Option 2: Individual domain variables (backward compatibility)
LDAP_DOMAIN=ldap.example.com
RADIUS_DOMAIN=radius.example.com

# Option 3: Single domain only
DOMAINS=ldap.example.com

# Let's Encrypt Settings
LETSENCRYPT_EMAIL=admin@example.com
ENVIRONMENT=development
STAGING=true                    # Use staging for testing
DRY_RUN=false

# Certificate Renewal
RENEWAL_INTERVAL=43200          # 12 hours in seconds

```

#### Domain Configuration Behavior:
- **If `DOMAINS` is set**: Uses the comma-separated list directly
- **If `DOMAINS` is not set**: Falls back to `${LDAP_DOMAIN},${RADIUS_DOMAIN}`
- **Supports 1-100 domains**: Let's Encrypt SAN certificate limit

## 📋 Usage Scenarios

### Single Domain Setup

For a single domain:

1. **Configure .env**:
```bash
DOMAINS=ldap.example.com
LETSENCRYPT_EMAIL=admin@example.com
STAGING=true
```

2. **Deploy and acquire certificate**:
```bash
make deploy
make init-certs
```

### Multiple Domain Setup (Recommended)

For multiple domains with SAN certificate:

1. **Configure .env**:
```bash
DOMAINS=ldap.example.com,radius.example.com
LETSENCRYPT_EMAIL=admin@example.com
STAGING=true
```

2. **Deploy and acquire multi-domain certificate**:
```bash
make deploy
make init-certs
```

### Production Deployment

For production with real certificates:

1. **Update .env for production**:
```bash
DOMAINS=ldap.yourdomain.com,radius.yourdomain.com
LETSENCRYPT_EMAIL=admin@yourdomain.com
STAGING=false                   # Use production Let's Encrypt
ENVIRONMENT=production
```

2. **Deploy with production settings**:
```bash
make clean                      # Clean staging certificates
make deploy
make init-certs
```

## 🔧 Available Commands

### Setup & Deployment
```bash
make env                        # Create .env from template
make build                      # Build certbot Docker image
make deploy                     # Start certbot service
make init-certs                 # Initialize certificates
```


### Operations
```bash
make status                     # Check certificate status
make logs                       # View certbot logs
make renew                      # Force certificate renewal
make restart                    # Restart certbot service
make stop                       # Stop certbot service
```

### Maintenance
```bash
make test                       # Test certificate validity
make clean                      # Clean containers and volumes
make show-config                # Display current configuration
```

## 📊 Monitoring & Status

### Check Certificate Status
```bash
make status
```

Example output:
```
✓ Certbot container is running
Certificate Status:
Domain: ldap.example.com
Valid until: 2024-12-07 10:30:00 UTC
Days remaining: 85
```

### View Logs
```bash
make logs
```

### Test Certificate Validity
```bash
make test
```

## 🔄 Certificate Renewal

### Automatic Renewal
- Certificates are checked every 12 hours (configurable)
- Automatic renewal occurs 30 days before expiration
- Post-renewal hooks can trigger service rebuilds

### Manual Renewal
```bash
# Force immediate renewal
make renew
```

### Renewal Workflow
1. Certbot checks certificate expiration
2. Renews if within 30 days of expiration
3. Updated certificates available in container
4. Other projects can copy updated certificates as needed

## 🔍 Troubleshooting

### Common Issues

#### "Certbot container not running"
```bash
make deploy
make status
```

#### "Certificate not found"
```bash
# Initialize certificates first
make init-certs
```

#### "Permission denied on certificate files"
```bash
# Certificates have correct permissions in container:
# 644 for cert.pem and fullchain.pem
# 640 for privkey.pem
# Use docker cp to copy with proper permissions
```

#### "Let's Encrypt rate limit exceeded"
```bash
# Switch to staging for testing
# Edit .env: STAGING=true
make clean
make deploy
make init-certs
```

### Debugging Commands

```bash
# Check container logs
docker logs standalone-certbot

# Inspect certificate files
docker exec standalone-certbot ls -la /etc/letsencrypt/live/

# Test domain resolution
nslookup ldap.example.com

# Check port 80 availability
netstat -tulpn | grep :80
```

## 🔐 Security Considerations

- **File Permissions**: Private keys are set to 640 (owner + group read)
- **Container Security**: Runs with minimal privileges
- **Network Isolation**: Uses dedicated Docker network
- **Log Management**: Configured log rotation and retention
- **Staging Environment**: Always test with Let's Encrypt staging first

## 📍 Certificate File Locations

When certbot container is running, certificate files are located at:

- **Container path**: `/etc/letsencrypt/live/{DOMAIN}/`
- **Certificate files**:
  - `cert.pem` - Certificate file
  - `privkey.pem` - Private key file  
  - `fullchain.pem` - Full certificate chain
- **Docker volume**: `standalone-certbot_letsencrypt`

### Manual Certificate Access
```bash
# Copy certificate files manually from running certbot container
docker cp standalone-certbot:/etc/letsencrypt/live/ldap.example.com/cert.pem ./cert.pem
docker cp standalone-certbot:/etc/letsencrypt/live/ldap.example.com/privkey.pem ./privkey.pem
docker cp standalone-certbot:/etc/letsencrypt/live/ldap.example.com/fullchain.pem ./fullchain.pem
```

## 🚀 Integration with Other Projects

This certbot service is designed to work with:

- **LDAP Project** - OpenLDAP with TLS support
- **FreeRADIUS Project** - RADIUS server with RadSec
- **Custom Projects** - Any Docker project needing TLS certificates

### Integration Pattern

1. **Start certbot service**: Acquires and manages certificates
2. **Projects copy certificates**: Each project copies certificates from certbot container
3. **Build services**: Projects include certificates at build time
4. **Deploy services**: Services use embedded certificates

## 📝 Example Workflows

### Development Setup
```bash
# Development with staging certificates
make env
# Edit .env: STAGING=true
make deploy && make init-certs
```

### Production Setup
```bash
# Production with real certificates
make env  
# Edit .env: STAGING=false, real domains
make deploy && make init-certs
```

### Adding New Domain
```bash
# Update .env with new domain in DOMAINS list
# Edit: DOMAINS=ldap.example.com,radius.example.com,new.example.com
make restart
make renew
```

## 📚 Related Documentation

- [Three-Project Architecture](../docs/03-THREE-PROJECT-ARCHITECTURE.md)
- [LDAP Project Integration](../ldap/README.md)
- [FreeRADIUS Project Integration](../freeradius/README.md)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## 🆘 Support

For issues specific to this certbot implementation:
1. Check the troubleshooting section above
2. Review logs: `make logs`
3. Test certificate validity: `make test`
4. Verify domain DNS resolution

For Let's Encrypt issues:
- [Let's Encrypt Community Forum](https://community.letsencrypt.org/)
- [Certbot Documentation](https://certbot.eff.org/docs/)

---

**This standalone certbot service is part of the three-project architecture providing independent, scalable certificate management for multiple authentication services.**