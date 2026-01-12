# Keycloak SAML Identity Provider

SAML 2.0 Identity Provider with LDAP user federation for enterprise authentication testing.

## User Flow

```
Step 1: Certificate Setup
┌─────────────────┐     ┌─────────────────┐
│    Certbot      │────▶│    Keycloak     │
│   (Port 80)     │     │  (build time)   │
└─────────────────┘     └─────────────────┘
        │                       │
        ▼                       ▼
   Let's Encrypt          certs copied to
   certificates           /opt/keycloak/conf/

Step 2: LDAP User Federation
┌─────────────────┐     ┌─────────────────┐
│    Keycloak     │────▶│    OpenLDAP     │
│   (Port 8443)   │     │   (Port 636)    │
└─────────────────┘     └─────────────────┘
        │                       │
        ▼                       ▼
   User lookup            Users synced
   via LDAPS              to Keycloak

Step 3: SAML SSO Authentication
┌──────┐    ┌─────────┐    ┌───────────┐    ┌──────────┐
│ User │───▶│ Web App │───▶│ Keycloak  │───▶│ OpenLDAP │
└──────┘    │  (SP)   │    │   (IdP)   │    └──────────┘
            └─────────┘    │  (:8443)  │         │
                           └───────────┘         │
                                 │               ▼
                                 │         ┌──────────┐
                                 ▼         │ User     │
                           ┌──────────┐    │ Verified │
                           │ SAML     │◄───└──────────┘
                           │ Assertion│
                           └──────────┘
                                 │
                                 ▼
                           ┌──────────┐
                           │ User     │
                           │ Logged In│
                           └──────────┘
```

## Prerequisites

- Certbot container running with certificates
- OpenLDAP container running with test users
- Docker and Docker Compose v2

## Directory Structure

```
keycloak/
├── .env                         # Environment configuration
├── .env.example                 # Template for .env
├── docker-compose.yml           # Docker service definition
├── Makefile                     # Build and management commands
├── docker/
│   └── certs/                   # TLS certificates (copied at build)
├── config/
│   └── realm-export.json        # SAML realm configuration
└── scripts/
    ├── copy-certs-for-build.sh  # Copy certs from certbot
    └── setup-realm.sh           # Configure LDAP federation
```

## Setup

### Step 1: Configure Environment

```bash
cd keycloak
make env
# Edit .env with your settings
```

Key variables in `.env`:

| Variable | Description | Example |
|----------|-------------|---------|
| `KEYCLOAK_DOMAIN` | Keycloak server hostname | `keycloak.example.com` |
| `KEYCLOAK_ADMIN` | Admin username | `admin` |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin password | `AdminPass123!` |
| `LDAP_HOST` | LDAP server hostname | `openldap` |
| `LDAP_PORT` | LDAP port (389 or 636) | `636` |
| `LDAP_DOMAIN` | LDAP domain for base DN | `ldap.example.com` |
| `LDAP_ADMIN_PASSWORD` | LDAP admin password | `SecureAdmin123!` |
| `CERTBOT_CERT_NAME` | Certificate directory name | `ldap.example.com` |

### Step 2: Deploy

```bash
make init
```

This runs: env → copy-certs → deploy → test

Or step by step:

```bash
make copy-certs    # Copy certificates from certbot
make deploy        # Start service
make test          # Test connectivity
make setup-realm   # Configure LDAP federation
```

## Test Users

Keycloak federates with OpenLDAP. These LDAP users are available:

| Username | LDAP Group | Role |
|----------|------------|------|
| `test-user-01` | wifi-users | Standard |
| `test-user-02` | wifi-guests | Guest |
| `test-user-03` | wifi-admins | Admin |
| `test-user-04` | external-users | Contractor |
| `test-user-05` | executives | VIP |

## SAML Configuration

### IdP Metadata URL

```
https://<domain>:8443/realms/saml-test/protocol/saml/descriptor
```

### Key Endpoints

| Endpoint | URL |
|----------|-----|
| Admin Console | `https://<domain>:8443/admin` |
| SSO | `https://<domain>:8443/realms/saml-test/protocol/saml` |
| SLO | `https://<domain>:8443/realms/saml-test/protocol/saml` |
| Metadata | `https://<domain>:8443/realms/saml-test/protocol/saml/descriptor` |

### Adding a SAML Service Provider

1. Access Keycloak admin console
2. Select "saml-test" realm
3. Go to Clients → Create client
4. Select "SAML" protocol
5. Configure:
   - Client ID: SP entity ID (from SP metadata)
   - Valid redirect URIs: ACS URL
   - Master SAML Processing URL: SP base URL
6. Save and configure attribute mappers

## Management Commands

| Command | Description |
|---------|-------------|
| `make env` | Create .env from template |
| `make init` | Full setup: copy-certs → deploy → test |
| `make copy-certs` | Copy certificates from certbot |
| `make deploy` | Start service |
| `make setup-realm` | Configure SAML realm with LDAP |
| `make stop` | Stop service |
| `make restart` | Restart service |
| `make logs` | View logs |
| `make logs-follow` | Follow logs in real-time |
| `make test` | Test connectivity |
| `make test-ldap` | Test LDAP federation |
| `make clean` | Remove containers and volumes |
| `make status` | Show service status |

## LDAP Federation

Keycloak connects to OpenLDAP using these settings:

| Setting | Value |
|---------|-------|
| Connection URL | `ldaps://openldap:636` |
| Users DN | `ou=users,dc=<domain>,dc=com` |
| Bind DN | `cn=admin,dc=<domain>,dc=com` |
| User Object Class | `inetOrgPerson` |
| Username Attribute | `uid` |
| Edit Mode | READ_ONLY |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 | HTTP | Admin console, health checks |
| 8443 | HTTPS | SAML endpoints, secure admin |

## Troubleshooting

### Keycloak not starting

```bash
docker compose logs --tail=50
```

Common issues:
- Certificate files missing (run `make copy-certs`)
- Port already in use
- Insufficient memory

### LDAP federation not working

```bash
# Check LDAP network connectivity
docker exec keycloak ping openldap

# Verify LDAP is running
docker ps | grep openldap
```

### Users not syncing

1. Access admin console
2. Go to User Federation → ldap
3. Click "Sync all users"
4. Check sync status

### Certificate errors

```bash
# Verify certbot has certificates
docker exec certbot ls -la /etc/letsencrypt/live/

# Re-copy certificates
make copy-certs
make restart
```

## Security Notes

- Production mode is enabled (`start` command)
- LDAPS (port 636) is used for encrypted LDAP connections
- Change default admin password before production use
- Consider enabling brute force protection in production
