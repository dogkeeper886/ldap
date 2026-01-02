# Enterprise Authentication Testing Platform

A comprehensive authentication testing platform for enterprise WiFi environments. This project provides a complete solution with independent authentication services: certificate management, LDAP directory services, RADIUS authentication, and SAML identity provider.

**Current Status**: All components complete - certbot, LDAP, FreeRADIUS, Mail server, and Keycloak SAML IdP are fully functional.

## 🎯 Project Overview

This platform provides authentication testing with:
- **Let's Encrypt certificate management** for TLS/SSL automation
- **LDAP directory authentication** with test users and Microsoft AD compatibility
- **RADIUS authentication server** with EAP protocol support
- **SAML 2.0 Identity Provider** with LDAP user federation
- **Mail server** for receiving email (SMTP/IMAP)

## 🏗️ Five-Project Architecture

This repository contains **five independent sub-projects** that work together to provide a complete authentication testing environment:

### 1. **Certificate Management** (`certbot/`)
- **Purpose**: Standalone multi-domain SSL/TLS certificate management
- **Technology**: Let's Encrypt with automated renewal
- **Ports**: 80 (HTTP challenge)
- **Function**: Provides certificates for both LDAP and RADIUS services

### 2. **LDAP Directory Service** (`ldap/`)
- **Purpose**: OpenLDAP authentication server with Microsoft AD compatibility
- **Technology**: OpenLDAP with custom schemas and test users
- **Ports**: 389 (LDAP), 636 (LDAPS)
- **Function**: Directory authentication backend for enterprise WiFi

### 3. **RADIUS Authentication Service** (`freeradius/`)
- **Purpose**: FreeRADIUS server with EAP protocol support
- **Technology**: FreeRADIUS with TLS/RadSec capabilities
- **Ports**: 1812/1813 (RADIUS), 2083 (RadSec)
- **Function**: RADIUS authentication for WiFi access points

### 4. **SAML Identity Provider** (`keycloak/`)
- **Purpose**: SAML 2.0 Identity Provider with LDAP user federation
- **Technology**: Keycloak with LDAP backend integration
- **Ports**: 8080 (HTTP), 8443 (HTTPS)
- **Function**: SAML SSO authentication for web applications

### 5. **Mail Server** (`mail/`)
- **Purpose**: Receive-only mail server
- **Technology**: docker-mailserver with Postfix/Dovecot
- **Ports**: 25 (SMTP), 993 (IMAPS)
- **Function**: Receive emails via IMAP

## 📖 Getting Started - Reading Order

To understand and deploy this authentication platform, please read the documentation in this specific sequence:

### Step 1: Certificate Foundation
**Read first**: [`certbot/README.md`](certbot/README.md)
- Understand certificate management architecture
- Learn multi-domain certificate acquisition
- Set up the certificate foundation for all services

### Step 2: LDAP Directory Service
**Read second**: [`ldap/README.md`](ldap/README.md)
- Deploy OpenLDAP authentication server
- Configure test users and Microsoft AD compatibility
- Understand LDAP integration with WiFi access points

### Step 3: RADIUS Authentication Service
**Read third**: [`freeradius/README.md`](freeradius/README.md)
- Deploy FreeRADIUS with EAP protocol support
- Configure RadSec (RADIUS over TLS)
- Test enterprise WiFi authentication flows

### Step 4: SAML Identity Provider
**Read fourth**: [`keycloak/README.md`](keycloak/README.md)
- Deploy Keycloak SAML 2.0 Identity Provider
- Configure LDAP user federation
- Set up SAML authentication for web applications

## 🔧 Architecture Benefits

✅ **Independent Deployment** - Each service deploys and scales independently  
✅ **Shared Certificate Lifecycle** - Single certificate management for all services  
✅ **Port Conflict Resolution** - No conflicts between services  
✅ **Modular Testing** - Test LDAP and RADIUS separately or together  
✅ **Production Ready** - Proper TLS encryption and security practices  

## 📁 Project Structure

```
ldap/
├── README.md              # This overview document
├── certbot/               # Certificate management project
├── ldap/                  # LDAP authentication project
├── freeradius/            # RADIUS authentication project
├── keycloak/              # SAML Identity Provider project
├── mail/                  # Mail server project
└── docs/                  # Architecture documentation
```

## 🚀 Use Cases

This platform supports various enterprise authentication testing scenarios:

- **WiFi Access Point Testing**: Validate AP configurations with real authentication backends
- **802.1X Development**: Test EAP protocols and certificate-based authentication
- **Network Access Control**: Integrate with NAC systems requiring LDAP/RADIUS
- **SAML SSO Integration**: Test SAML 2.0 authentication for web applications
- **Enterprise Migration**: Test authentication flows before production deployment
- **Security Validation**: Verify TLS configurations and authentication policies

## 📋 Prerequisites

Before starting, ensure you have:
- Linux server with Docker and Docker Compose v2
- Domain names for your services (e.g., ldap.example.com, radius.example.com, keycloak.example.com)
- DNS records pointing to your server
- Required ports available (25, 80, 389, 636, 993, 1812, 1813, 2083, 8080, 8443)

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Each sub-project accepts pull requests independently.

---

**Start with [`certbot/README.md`](certbot/README.md) to begin your authentication testing journey!** 🔒