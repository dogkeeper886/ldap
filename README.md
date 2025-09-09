# LDAP Authentication Server for WiFi Testing

A production-ready LDAP server designed specifically for testing WiFi authentication with enterprise access points (RUCKUS One, Cisco, Aruba, etc.). Deploy a fully functional LDAP server with TLS support and test users in minutes.

## 🎯 Project Goal

Provide a simple, reliable LDAP authentication backend for:
- **WiFi WPA2/WPA3 Enterprise authentication testing**
- **802.1X EAP authentication development**
- **Network access control (NAC) testing**
- **RADIUS server integration testing**
- **Enterprise access point configuration validation**

## ⚡ Quick Start

### Prerequisites
- Linux server with Docker and Docker Compose v2
- Domain name pointing to your server
- Ports 389, 636, and 80 available

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/dogkeeper886/ldap.git
cd ldap

# Create environment configuration
cp .env.example .env

# Edit .env with your settings:
# - LDAP_DOMAIN (your domain, e.g., ldap.example.com)
# - LDAP_ADMIN_PASSWORD (admin password)
# - LETSENCRYPT_EMAIL (for SSL certificates)
nano .env
```

### 2. Deploy LDAP Server

```bash
# Initialize and start the LDAP server with TLS certificates
make init

# This command will:
# 1. Build Docker images
# 2. Obtain Let's Encrypt certificates
# 3. Start OpenLDAP with TLS support
# 4. Configure the directory structure
```

### 3. Add Test Users

```bash
# Create test users and groups
make setup-users

# This creates three test users ready for authentication testing
```

### 4. Microsoft AD Compatibility (Automatic)
MS AD attributes are **automatically added** during user setup:
- `sAMAccountName` - Windows-style username
- `userPrincipalName` - UPN format (user@domain.com)  
- Compatible with enterprise WiFi APs expecting MS AD

No additional commands needed - included in `make setup-users`

## 👥 Test Users

After running `make setup-users`, the following test accounts are available:

| Username | Password | Full Name | Role | Department |
|----------|----------|-----------|------|------------|
| `test-user-01` | `TestPass123!` | John Smith | IT Administrator | IT |
| `test-user-02` | `TestPass456!` | Jane Doe | Network Engineer | IT |
| `test-user-03` | `GuestPass789!` | Mike Johnson | Guest User | Guest |

### User Attributes
Each user has complete attributes for policy testing:
- **Email**: `firstname.lastname@example.com`
- **Phone**: Unique numbers for each user
- **Groups**: IT staff, guests, or all-users
- **Department**: IT or Guest (stored in `ou` attribute)

## 🔧 Access Point Configuration

### RUCKUS One Configuration
```
Server Type: LDAP/LDAPS
Server: your-domain.com
Port: 636 (LDAPS) or 389 (LDAP)
Base DN: dc=your,dc=domain,dc=com
Admin DN: cn=admin,dc=your,dc=domain,dc=com
Admin Password: [your admin password]
Search Filter: uid=%s
Key Attribute: [leave empty]
```

### Microsoft AD Compatible Configuration
For access points expecting Active Directory attributes:
```
Search Filter Options:
- Standard LDAP: uid=%s
- MS AD Style: (sAMAccountName=%s)
- UPN Style: (userPrincipalName=%s)
- Combined: (|(sAMAccountName=%s)(userPrincipalName=%s))
```

### Important Configuration Notes
- **Base DN**: Automatically derived from your domain (example.com → dc=example,dc=com)
- **Search Filter**: Use `uid=%s` for standard LDAP or MS AD filters above
- **Key Attribute**: Leave empty to avoid filter conflicts
- **User Search Base**: The entire directory is searched from Base DN
- **MS AD Attributes**: Automatically enabled with `make setup-users`

## 📁 Project Structure

```
ldap/
├── docker-compose.yml      # Service orchestration
├── Makefile               # Management commands
├── .env.example           # Environment template
├── docker/
│   ├── openldap/         # OpenLDAP container configuration
│   └── certbot/          # Let's Encrypt automation
├── scripts/
│   ├── setup-users.sh    # User creation script
│   └── init-certificates.sh  # Certificate initialization
└── tests/                # Testing scripts
```

## 🔐 Security Features

- **TLS/SSL Encryption**: Automatic Let's Encrypt certificates
- **SSHA Password Hashing**: Secure password storage
- **Network Isolation**: Docker network security
- **Access Control**: LDAP ACLs for data protection
- **Certificate Auto-Renewal**: Automated certificate updates

## 🛠️ Common Operations

### View LDAP Directory
```bash
# Show all users and groups
make view-ldap
```

### Check Service Health
```bash
# Verify services are running correctly
make health
```

### View Logs
```bash
# Check recent logs
make logs

# Follow logs in real-time
make logs-follow
```

### Restart Services
```bash
# Restart LDAP server
make restart
```

### MS AD Compatibility
MS AD attributes are automatically included in the standard workflow:
```bash
# Standard setup includes MS AD attributes
make setup-users
```

### Backup and Restore
```bash
# Create backup
make backup

# Restore from backup
make restore FILE=backup-file.tar.gz
```

## 🧪 Testing Authentication

### From Command Line
```bash
# Test LDAP authentication (port 389)
ldapwhoami -x -H ldap://your-domain.com:389 \
  -D "uid=test-user-01,ou=users,dc=your,dc=domain,dc=com" \
  -w "TestPass123!"

# Test LDAPS authentication (port 636)
ldapwhoami -x -H ldaps://your-domain.com:636 \
  -D "uid=test-user-01,ou=users,dc=your,dc=domain,dc=com" \
  -w "TestPass123!"

# Test MS AD style authentication (automatically enabled)
ldapsearch -x -H ldaps://your-domain.com:636 \
  -D "cn=admin,dc=your,dc=domain,dc=com" -w "admin-password" \
  -b "dc=your,dc=domain,dc=com" \
  "(|(sAMAccountName=test-user-01)(userPrincipalName=test-user-01@your-domain.com))"
```

### WiFi Client Testing
1. Configure your device for WPA2/WPA3 Enterprise
2. Choose EAP method (usually PEAP or EAP-TTLS)
3. Enter username: `test-user-01`
4. Enter password: `TestPass123!`
5. Accept the certificate (if prompted)

## 🔍 Troubleshooting

### Enable Debug Logging
```bash
# Check current logs
docker logs openldap --tail 50

# Enable verbose logging for troubleshooting
docker exec openldap slapcat -n 0 | grep olcLogLevel
```

### Common Issues

**Authentication Fails**
- Verify the domain name in your Base DN matches your LDAP_DOMAIN
- Ensure you're using the correct password (check for special characters)
- Verify the user exists: `make view-ldap`
- For APs expecting MS AD: MS AD attributes are automatically enabled with `make setup-users`
- Check if AP is searching for sAMAccountName or userPrincipalName instead of uid

**Certificate Issues**
- Check certificate status: `make health`
- Verify DNS points to your server
- Ensure port 80 is open for Let's Encrypt validation

**Connection Refused**
- Check firewall rules for ports 389, 636
- Verify containers are running: `docker ps`
- Check bind address in docker-compose.yml

## 🚀 Advanced Configuration

### Custom Users
Edit `scripts/setup-users.sh` to add your own users with specific attributes.

### Custom Schema
Add custom LDAP schemas in `docker/openldap/schema/` for specialized attributes.

### Replication
Configure LDAP replication for high availability in production environments.

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests.

## 📮 Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

**Ready for Enterprise WiFi Authentication Testing!** 🔒📡