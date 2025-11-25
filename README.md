# Enterprise Authentication Testing Platform

A comprehensive authentication testing platform for enterprise WiFi environments. This project provides a complete solution with three independent authentication services: certificate management, LDAP directory services, and RADIUS authentication.

**Current Status**: All components complete - certbot, LDAP, and FreeRADIUS are fully functional.

## 🎯 Project Overview

This platform provides authentication testing with:
- **Let's Encrypt certificate management** for TLS/SSL automation
- **LDAP directory authentication** with test users and Microsoft AD compatibility  
- **RADIUS authentication server** with EAP protocol support

## 🏗️ Three-Project Architecture

This repository contains **three independent sub-projects** that work together to provide a complete authentication testing environment:

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
│   └── README.md         # Certificate deployment guide
├── ldap/                 # LDAP authentication project  
│   └── README.md         # LDAP deployment guide
├── freeradius/           # RADIUS authentication project
│   └── README.md         # RADIUS deployment guide
└── docs/                 # Architecture documentation
    ├── 01-brainstorming-session-results.md
    ├── 02-PRD.md
    └── 03-THREE-PROJECT-ARCHITECTURE.md
```

## 🚀 Use Cases

This platform supports various enterprise authentication testing scenarios:

- **WiFi Access Point Testing**: Validate AP configurations with real authentication backends
- **802.1X Development**: Test EAP protocols and certificate-based authentication  
- **Network Access Control**: Integrate with NAC systems requiring LDAP/RADIUS
- **Enterprise Migration**: Test authentication flows before production deployment
- **Security Validation**: Verify TLS configurations and authentication policies

## 📋 Prerequisites

Before starting, ensure you have:
- Linux server with Docker and Docker Compose v2
- Domain names for your services (e.g., ldap.example.com, radius.example.com)
- DNS records pointing to your server
- Required ports available (80, 389, 636, 1812, 1813, 2083)

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Each sub-project accepts pull requests independently.

---

**Start with [`certbot/README.md`](certbot/README.md) to begin your authentication testing journey!** 🔒