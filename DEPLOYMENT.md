# LDAP Server Deployment Guide

This guide provides step-by-step instructions for deploying the LDAP server for WiFi authentication testing.

## 🎯 Deployment Overview

The deployment process consists of:
1. **Infrastructure Setup** - GCP VM and network configuration
2. **Domain Configuration** - DNS setup and domain validation
3. **Service Deployment** - Docker containers and LDAP services
4. **Certificate Management** - Let's Encrypt TLS certificates
5. **User Configuration** - Test user setup and validation
6. **Integration Testing** - RUCKUS One integration verification

## 🏗️ Infrastructure Setup

### GCP VM Requirements

**Minimum Specifications:**
- **Instance Type**: e2-micro (1 vCPU, 1GB RAM)
- **Boot Disk**: 20GB SSD
- **Operating System**: Ubuntu 22.04 LTS or Debian 12
- **Network**: Static external IP address

**Recommended Specifications:**
- **Instance Type**: e2-small (2 vCPU, 2GB RAM)
- **Boot Disk**: 30GB SSD
- **Region**: Closest to WiFi AP location

### Create GCP VM

```bash
# Create VM instance
gcloud compute instances create ldap-server \
    --zone=us-central1-a \
    --machine-type=e2-small \
    --subnet=default \
    --address=ldap-server-ip \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=ldap-server \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=30GB \
    --boot-disk-type=pd-ssd \
    --boot-disk-device-name=ldap-server

# Reserve static IP
gcloud compute addresses create ldap-server-ip \
    --region=us-central1
```

### Firewall Configuration

```bash
# Allow LDAPS traffic (port 636)
gcloud compute firewall-rules create allow-ldaps \
    --allow tcp:636 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow LDAPS for WiFi authentication" \
    --target-tags ldap-server

# Allow HTTP for Let's Encrypt (port 80)
gcloud compute firewall-rules create allow-http-acme \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTP for Let's Encrypt ACME challenges" \
    --target-tags ldap-server

# Allow SSH (if not already configured)
gcloud compute firewall-rules create allow-ssh-ldap \
    --allow tcp:22 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow SSH access to LDAP server" \
    --target-tags ldap-server
```

## 🌐 Domain Configuration

### DNS Setup

Configure your domain to point to the GCP VM's external IP:

```bash
# Get the external IP
gcloud compute instances describe ldap-server \
    --zone=us-central1-a \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

Create DNS A record:
- **Name**: `ldap` (or your preferred subdomain)
- **Type**: `A`
- **Value**: `[EXTERNAL_IP]`
- **TTL**: `300` (5 minutes)

Example: `ldap.yourdomain.com` → `34.123.456.789`

### Verify DNS Resolution

```bash
# Test DNS resolution
dig ldap.yourdomain.com

# Verify from different locations
nslookup ldap.yourdomain.com 8.8.8.8
```

## 🐳 Service Deployment

### 1. Install Dependencies

Connect to your GCP VM and install required software:

```bash
# SSH to the VM
gcloud compute ssh ldap-server --zone=us-central1-a

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Install additional tools
sudo apt install -y git make bc netcat-openbsd openssl dig

# Log out and back in for group changes
exit
gcloud compute ssh ldap-server --zone=us-central1-a
```

### 2. Deploy LDAP Services

```bash
# Clone or upload the project files
# (Upload your project directory to the VM)

# Navigate to project directory
cd ldap

# Create environment configuration
make env

# Edit environment file
nano .env
```

**Required .env Configuration:**
```bash
LDAP_DOMAIN=ldap.yourdomain.com
LETSENCRYPT_EMAIL=admin@yourdomain.com
LDAP_ADMIN_PASSWORD=your_very_secure_admin_password_here
LDAP_CONFIG_PASSWORD=your_very_secure_config_password_here
ENVIRONMENT=production

# Test user passwords (change these!)
TEST_USER_PASSWORD=SecureTestPass123!
GUEST_USER_PASSWORD=SecureGuestPass789!
ADMIN_USER_PASSWORD=SecureAdminPass456!
CONTRACTOR_PASSWORD=SecureContractorPass321!
VIP_PASSWORD=SecureVipPass654!
```

### 3. Complete Deployment

```bash
# Run complete initialization
make init

# This will:
# 1. Acquire Let's Encrypt certificates
# 2. Deploy Docker services
# 3. Set up test users
# 4. Run health checks
```

## 🔐 Certificate Management

### Initial Certificate Acquisition

The `make init` command handles certificate acquisition automatically. For manual control:

```bash
# Initialize certificates only
make init-certs

# Check certificate status
openssl x509 -in volumes/certificates/live/ldap.yourdomain.com/cert.pem -text -noout
```

### Certificate Renewal

Certificates renew automatically. For manual management:

```bash
# Force certificate renewal
make force-renew-certs

# Check renewal logs
make logs-certbot
```

## 👥 User Configuration

### Verify Test Users

```bash
# Set up users (automatic with make init)
make setup-users

# Test user authentication
make test-auth

# View all users
make view-ldap
```

### Custom User Configuration

To add additional users:

1. **Edit LDIF file:**
```bash
nano ldifs/02-users.ldif
```

2. **Add user entry:**
```ldif
# Custom User
dn: uid=custom-user,ou=users,dc=yourdomain,dc=com
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: custom-user
cn: Custom User Name
sn: Name
displayName: Custom User Name
mail: custom.user@yourdomain.com
telephoneNumber: +1-555-0199
department: IT
employeeType: Full-Time
# Password will be set via script
```

3. **Redeploy users:**
```bash
make setup-users
```

## 🧪 Integration Testing

### 1. LDAP Connectivity Test

```bash
# Test LDAPS connection
make test-tls

# Manual connection test
ldapsearch -x -H ldaps://ldap.yourdomain.com:636 \
    -D "uid=test-user-01,ou=users,dc=yourdomain,dc=com" \
    -w "SecureTestPass123!" \
    -b "" -s base
```

### 2. Attribute Validation

```bash
# Test RUCKUS required attributes
make test-attributes

# Manual attribute query
ldapsearch -x -H ldaps://ldap.yourdomain.com:636 \
    -D "cn=admin,dc=yourdomain,dc=com" \
    -w "your_admin_password" \
    -b "uid=test-user-01,ou=users,dc=yourdomain,dc=com" \
    displayName mail telephoneNumber department
```

### 3. Performance Testing

```bash
# Run performance tests
make test-performance

# Check resource usage
make status
```

## 📡 RUCKUS One Configuration

### 1. Identity Provider Settings

Configure RUCKUS One with these settings:

**LDAP Server Configuration:**
- **Server Type**: Generic LDAP
- **Server Address**: `ldap.yourdomain.com`
- **Port**: `636`
- **Security**: `LDAPS (SSL/TLS)`
- **Base DN**: `dc=yourdomain,dc=com`
- **Bind DN**: `cn=admin,dc=yourdomain,dc=com`
- **Bind Password**: `[your_admin_password]`

**User Search Configuration:**
- **User Search Base**: `ou=users,dc=yourdomain,dc=com`
- **User Search Filter**: `(uid=%s)`
- **Username Attribute**: `uid`

### 2. Identity Mapping

Configure attribute mapping:

| RUCKUS Field | LDAP Attribute | Sample Value |
|--------------|----------------|--------------|
| Display Name | displayName | "Test User One" |
| Email | mail | "test.user01@yourdomain.com" |
| Phone | telephoneNumber | "+1-555-0101" |
| Custom Attribute 1 | department | "IT" |

### 3. Access Policies

Create access policies based on department:

**IT Department Policy:**
- **Condition**: Custom Attribute 1 = "IT"
- **Access**: Full network access
- **Bandwidth**: Unlimited
- **Time Restrictions**: None

**Guest Policy:**
- **Condition**: Custom Attribute 1 = "Guest"
- **Access**: Internet only
- **Bandwidth**: 10 Mbps
- **Time Restrictions**: 8 hours

**Executive Policy:**
- **Condition**: Custom Attribute 1 = "Executive"
- **Access**: VIP network access
- **Bandwidth**: Unlimited
- **Priority**: High

## 🔍 Verification & Testing

### 1. End-to-End WiFi Test

1. **Configure WiFi SSID** with LDAP authentication
2. **Connect test device** to WiFi network
3. **Enter credentials** for test-user-01
4. **Verify network access** based on department policy

### 2. User Authentication Test

```bash
# Test each user account
users=("test-user-01" "test-user-02" "test-user-03" "test-user-04" "test-user-05")
passwords=("SecureTestPass123!" "SecureGuestPass789!" "SecureAdminPass456!" "SecureContractorPass321!" "SecureVipPass654!")

for i in "${!users[@]}"; do
    echo "Testing ${users[$i]}..."
    ldapsearch -x -H ldaps://ldap.yourdomain.com:636 \
        -D "uid=${users[$i]},ou=users,dc=yourdomain,dc=com" \
        -w "${passwords[$i]}" \
        -b "" -s base >/dev/null 2>&1 && echo "✓ Success" || echo "✗ Failed"
done
```

### 3. System Health Verification

```bash
# Comprehensive health check
make health-verbose

# Monitor system resources
watch -n 5 'make status'

# Check logs for errors
make logs | grep -i error
```

## 📊 Monitoring & Maintenance

### 1. Health Monitoring

Set up regular health checks:

```bash
# Add to crontab for regular monitoring
crontab -e

# Add these lines:
# Check health every 15 minutes
*/15 * * * * cd /home/user/ldap && make health >> /var/log/ldap-health.log 2>&1

# Daily backup at 2 AM
0 2 * * * cd /home/user/ldap && make backup >> /var/log/ldap-backup.log 2>&1
```

### 2. Log Management

```bash
# View logs
make logs

# Follow logs in real-time
make logs-follow

# Archive old logs
sudo logrotate -f /etc/logrotate.conf
```

### 3. Performance Monitoring

```bash
# Resource usage monitoring
make status

# Performance metrics
docker stats

# Disk space monitoring
df -h
```

## 🚨 Troubleshooting

### Common Deployment Issues

**Certificate Acquisition Fails:**
```bash
# Check DNS resolution
dig ldap.yourdomain.com

# Verify port 80 is accessible
curl http://ldap.yourdomain.com

# Check certbot logs
make logs-certbot

# Manual certificate debugging
docker run --rm -p 80:80 certbot/certbot:v2.7.4 certonly --standalone --dry-run -d ldap.yourdomain.com
```

**LDAP Service Won't Start:**
```bash
# Check container logs
make logs-ldap

# Verify volumes are mounted
docker inspect openldap

# Check certificate permissions
ls -la volumes/certificates/live/ldap.yourdomain.com/
```

**Authentication Failures:**
```bash
# Test admin access
ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=yourdomain,dc=com" \
    -w "your_admin_password" \
    -b "dc=yourdomain,dc=com"

# Verify user exists
make view-ldap | grep test-user-01

# Reset user passwords
make setup-users
```

**Performance Issues:**
```bash
# Check resource usage
make status
docker stats

# Increase VM resources if needed
gcloud compute instances stop ldap-server --zone=us-central1-a
gcloud compute instances set-machine-type ldap-server --machine-type=e2-medium --zone=us-central1-a
gcloud compute instances start ldap-server --zone=us-central1-a
```

### Recovery Procedures

**Complete Service Recovery:**
```bash
# Stop all services
make stop

# Clean up containers
make clean

# Restore from backup (if needed)
make restore FILE=volumes/backups/backup-latest.tar.gz

# Redeploy services
make deploy

# Verify functionality
make test
```

**Certificate Recovery:**
```bash
# Force certificate renewal
make force-renew-certs

# If renewal fails, check DNS and restart process
make init-certs
```

## ✅ Production Checklist

Before going live with production WiFi:

### Security Checklist
- [ ] Strong admin passwords configured
- [ ] Test user passwords changed from defaults
- [ ] TLS certificates valid and trusted
- [ ] Firewall rules properly configured
- [ ] No unnecessary services running
- [ ] Regular backups scheduled

### Functionality Checklist
- [ ] All health checks passing
- [ ] Authentication tests successful
- [ ] Attribute retrieval working
- [ ] TLS configuration secure
- [ ] RUCKUS One integration tested
- [ ] End-to-end WiFi authentication working

### Operational Checklist
- [ ] Monitoring configured
- [ ] Log management set up
- [ ] Backup strategy implemented
- [ ] Documentation updated
- [ ] Team trained on operations
- [ ] Emergency procedures documented

### Final Verification
```bash
# Run production readiness check
make prod-check

# Comprehensive test suite
make test

# Performance validation
make test-performance

# Security validation
make test-tls
```

## 📞 Support & Maintenance

### Regular Maintenance Tasks

**Weekly:**
- Check health status
- Review logs for errors
- Verify backup completion
- Monitor resource usage

**Monthly:**
- Update Docker images
- Review security settings
- Test disaster recovery
- Audit user accounts

**Quarterly:**
- Security assessment
- Performance review
- Documentation update
- Team training refresh

### Emergency Contacts

Document your emergency procedures and contact information:

1. **System Administrator**: [Contact info]
2. **Network Administrator**: [Contact info]
3. **Security Team**: [Contact info]
4. **Backup Administrator**: [Contact info]

### Additional Resources

- [Architecture Documentation](docs/architecture.md)
- [Product Requirements](docs/prd.md)
- [RUCKUS One Documentation](https://docs.ruckuswireless.com/)
- [OpenLDAP Documentation](https://www.openldap.org/doc/)

---

**Deployment completed successfully!** Your LDAP server is ready for WiFi authentication testing with RUCKUS One Access Points.