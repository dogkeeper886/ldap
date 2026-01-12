# Enterprise Authentication Testing Platform

Authentication testing platform for enterprise WiFi and SAML SSO. Five independent services: certbot, LDAP, FreeRADIUS, Keycloak, and Mail server.

## Architecture

```
┌─────────────┐
│   Certbot   │──► Let's Encrypt Certificates
│  (Port 80)  │           │
└─────────────┘           │
        ┌─────────────────┼─────────────────┬─────────────┐
        ▼                 ▼                 ▼             ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐ ┌───────────┐
│   OpenLDAP  │◄──│  Keycloak   │   │ FreeRADIUS  │ │Mail Server│
│ (389, 636)  │   │(8080, 8443) │   │(1812-13,2083)│ │ (25, 993) │
└─────────────┘   └─────────────┘   └─────────────┘ └───────────┘
                  User Federation
```

## Quick Start

```bash
# 1. Deploy certificates
cd certbot && make env && make deploy && cd ..

# 2. Deploy LDAP
cd ldap && make env && make init && make setup-users && cd ..

# 3. Deploy FreeRADIUS
cd freeradius && make env && make init && cd ..

# 4. Deploy Keycloak
cd keycloak && make env && make init && cd ..

# 5. Deploy Mail server
cd mail && make env && make deploy && cd ..
```

## Services

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

## Documentation

| Order | Service | README |
|-------|---------|--------|
| 1 | Certificates | [`certbot/README.md`](certbot/README.md) |
| 2 | LDAP | [`ldap/README.md`](ldap/README.md) |
| 3 | FreeRADIUS | [`freeradius/README.md`](freeradius/README.md) |
| 4 | Keycloak | [`keycloak/README.md`](keycloak/README.md) |
| 5 | Mail | [`mail/README.md`](mail/README.md) |

## Prerequisites

- Linux server with Docker and Docker Compose v2
- Domain names pointing to your server
- Ports available: 25, 80, 389, 636, 993, 1812, 1813, 2083, 8080, 8443

## Use Cases

- WiFi access point testing with LDAP/RADIUS backends
- 802.1X and EAP protocol development
- SAML SSO integration testing
- Enterprise authentication migration validation