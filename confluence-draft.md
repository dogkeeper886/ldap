# LDAP Directory Service

## Overview

A Docker-based LDAP directory service with TLS certificate management for enterprise WiFi authentication testing.

**Server**: `ldap.tsengsyu.com`
**Status**: Production-ready

---

## Ruckus One LDAP Configuration

Navigate to **Network Control → Service Catalog → Directory Server → Add Directory Server**.

### Directory Server Settings

| Field | Value |
|-------|-------|
| **Profile Name** | `ldap.tsengsyu.com` |
| **Server Type** | LDAP Server |
| **Enable TLS encryption** | Enabled (toggle ON) |
| **FQDN or IP Address** | `ldap.tsengsyu.com` |
| **Port** | `636` |
| **Base Domain Name** | `dc=ldap,dc=tsengsyu,dc=com` |
| **Admin Domain Name** | `cn=admin,dc=ldap,dc=tsengsyu,dc=com` |
| **Admin Password** | `SecureAdmin123!` |
| **Key Attribute** | `uid` |
| **Search Filter** | |

### Identity Attributes & Claims Mapping

| Field | Input |
|-------|-------|
| **Identity Display Name** | `displayName` |
| **Identity Email** | `mail` |
| **Identity Phone** | `telephoneNumber` or `mobile` |

| Field | Attribute Type | Claim Name |
|-------|----------------|------------|
| **Identity Attribute 1** (First Name) | String | `givenName` |
| **Identity Attribute 2** (Last Name) | String | `sn` |
| **Identity Attribute 3** (Roles) | String | `title` or `employeeType` |
| **Identity Attribute 4** (Groups) | String | `memberOf` |

Click **Test Connection** to verify connectivity before saving.

---

## Test Users

**User DN Format**: `uid=<username>,ou=users,dc=ldap,dc=tsengsyu,dc=com`

### Full Attributes Table

| Attribute | test-user-01 | test-user-02 | test-user-03 | test-user-04 | test-user-05 |
|-----------|--------------|--------------|--------------|--------------|--------------|
| **Password** | `TestPass123!` | `GuestPass789!` | `AdminPass456!` | `ContractorPass321!` | `VipPass654!` |
| **displayName** | Test User One - IT Employee | Guest User - Visitor | Admin User - System Administrator | Contractor User - External | VIP User - Executive |
| **mail** | test.user01@example.com | guest.user@example.com | admin.user@example.com | contractor@example.com | vip.user@example.com |
| **telephoneNumber** | +1-555-0101 | +1-555-0102 | +1-555-0103 | +1-555-0104 | +1-555-0105 |
| **mobile** | +1-555-9101 | +1-555-9102 | +1-555-9103 | +1-555-9104 | +1-555-9105 |
| **givenName** | Test User | Guest | Admin | Contractor | VIP |
| **sn** | One | User | User | User | User |
| **title** | IT Support Specialist | Visitor | Senior System Administrator | Technical Consultant | Chief Technology Officer |
| **employeeType** | Full-Time | Temporary | Full-Time | Contractor | Executive |
| **ou** | IT Department | External | IT Operations | Professional Services | Executive Management |
| **memberOf** | wifi-users | wifi-guests | wifi-admins | external-users | executives |

### Mapping Options

| Field | Option A | Option B |
|-------|----------|----------|
| **Phone** | `telephoneNumber` (office) | `mobile` (cell) |
| **Roles** | `title` (job title) | `employeeType` (employment status) |

### Groups

| Group | Description | Members |
|-------|-------------|---------|
| wifi-users | Standard WiFi access | test-user-01, test-user-04, test-user-05 |
| wifi-admins | Administrative WiFi access | test-user-03 |
| wifi-guests | Guest WiFi access (limited) | test-user-02 |
| it-department | IT department staff | test-user-01, test-user-03 |
| external-users | External contractors | test-user-04 |
| executives | Executive team (VIP) | test-user-05 |

---

## Verify LDAP Connection

Before configuring Ruckus One, verify the LDAP server is accessible using `ldapsearch`:

### Test Admin Bind (LDAPS)
```bash
ldapsearch -x -H ldaps://ldap.tsengsyu.com:636 \
  -D "cn=admin,dc=ldap,dc=tsengsyu,dc=com" \
  -w "SecureAdmin123!" \
  -b "dc=ldap,dc=tsengsyu,dc=com" \
  "(objectClass=inetOrgPerson)"
```

### Test User Authentication
```bash
ldapsearch -x -H ldaps://ldap.tsengsyu.com:636 \
  -D "uid=test-user-01,ou=users,dc=ldap,dc=tsengsyu,dc=com" \
  -w "TestPass123!" \
  -b "dc=ldap,dc=tsengsyu,dc=com" \
  "(uid=test-user-01)"
```

### Expected Output
A successful connection returns user entries with attributes like `uid`, `cn`, `mail`, `displayName`, etc.

---

# Container Setup (Reference)

The following sections document how the LDAP server is deployed and maintained.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │       LDAP Directory Service            │
                    ├─────────────────────────────────────────┤
                    │                                         │
                    │  ┌──────────────┐                       │
                    │  │   Certbot    │                       │
                    │  │   Port 80    │                       │
                    │  │ (Let's Encrypt)                      │
                    │  └──────┬───────┘                       │
                    │         │                               │
                    │         │ TLS Certificates              │
                    │         ▼                               │
                    │  ┌──────────────┐                       │
                    │  │     LDAP     │                       │
                    │  │ Ports 389,636│                       │
                    │  │  (OpenLDAP)  │                       │
                    │  └──────────────┘                       │
                    │                                         │
                    └─────────────────────────────────────────┘
```

| Service | Technology | Ports | Purpose |
|---------|------------|-------|---------|
| **Certbot** | Let's Encrypt | 80 | SSL/TLS certificate management with auto-renewal |
| **LDAP** | OpenLDAP 1.5.0 | 389 (LDAP), 636 (LDAPS) | Directory authentication with MS AD compatibility |

## Prerequisites

- Linux server with Docker and Docker Compose v2
- Domain name (e.g., `ldap.example.com`)
- DNS A record pointing to your server
- Available ports: 80, 389, 636

## Quick Start

### Step 1: Clone Repository

```bash
git clone https://github.com/dogkeeper886/ldap.git
cd ldap
```

### Step 2: Deploy Certificates

```bash
cd certbot
make env          # Creates .env from template
# Edit .env with your domains and email
make deploy       # Start certbot service
```

### Step 3: Deploy LDAP

```bash
cd ../ldap
make env          # Creates .env from template
# Edit .env with your configuration
make init         # Copy certs, build, deploy
make setup-users  # Create test users with passwords
```

## Common Commands

All services use Makefile for consistent operations:

| Command | Description |
|---------|-------------|
| `make env` | Create `.env` from template |
| `make deploy` | Start the service |
| `make stop` | Stop the service |
| `make restart` | Restart the service |
| `make logs` | View logs |
| `make logs-follow` | Follow logs in real-time |
| `make clean` | Remove containers and volumes |

### Service-Specific Commands

**Certbot**:
| Command | Description |
|---------|-------------|
| `make renew` | Force certificate renewal |

**LDAP**:
| Command | Description |
|---------|-------------|
| `make init` | Full setup (certs + deploy + users) |
| `make copy-certs` | Copy certificates from certbot |
| `make build-tls` | Build with TLS certificates |
| `make setup-users` | Create test users with passwords |
| `make backup` | Export LDAP data to LDIF |

## Troubleshooting

### Certificate Issues
```bash
cd certbot
make logs           # Check certbot logs
make deploy         # Re-run certificate acquisition
```

### LDAP Connection Issues
```bash
cd ldap
make logs           # Check LDAP logs
ldapsearch -x -H ldap://localhost -b "dc=ldap,dc=tsengsyu,dc=com"  # Test connection
```

## Repository

**GitHub**: https://github.com/dogkeeper886/ldap
