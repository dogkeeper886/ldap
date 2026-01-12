# FreeRADIUS Server

RADIUS authentication server with TLS/EAP support using Let's Encrypt certificates.

## User Flow

```
Step 1: Certificate Setup
┌─────────────────┐     ┌─────────────────┐
│    Certbot      │────▶│   FreeRADIUS    │
│  (Port 80)      │     │  (build time)   │
└─────────────────┘     └─────────────────┘
        │                       │
        ▼                       ▼
   Let's Encrypt          certs copied to
   certificates           /etc/raddb/certs/

Step 2: WiFi Client Authentication
┌──────┐    ┌─────────┐    ┌─────────────┐
│ User │───▶│ WiFi AP │───▶│ FreeRADIUS  │
└──────┘    └─────────┘    │ (1812/UDP)  │
                           └─────────────┘
                                 │
                                 ▼
                           ┌───────────┐
                           │ Access    │
                           │ Granted   │
                           └───────────┘

Step 3: RadSec (RADIUS over TLS)
┌─────────────┐    ┌─────────────┐
│ NAS/Client  │───▶│ FreeRADIUS  │
│ (TLS)       │    │ (2083/TCP)  │
└─────────────┘    └─────────────┘
                         │
                         ▼
                   ┌───────────┐
                   │ Secure    │
                   │ Auth Done │
                   └───────────┘
```

## Prerequisites

- Certbot container running with certificates for your RADIUS domain
- Docker and Docker Compose v2

## Directory Structure

```
freeradius/
├── .env                         # Environment configuration
├── .env.example                 # Template for .env
├── docker-compose.yml           # Docker service definition
├── Makefile                     # Build and management commands
├── docker/freeradius/
│   ├── Dockerfile               # Container build instructions
│   ├── entrypoint.sh            # Startup script
│   ├── setup-tls.sh             # TLS certificate configuration
│   ├── certs/                   # Certificates (copied at build time)
│   └── users/
│       └── users                # Test user definitions
└── scripts/
    ├── copy-certs-for-build.sh  # Copy certs from certbot
    ├── setup-users.sh           # Update user passwords
    └── test-all-users.sh        # Test all users
```

## Setup

### Step 1: Configure Environment

```bash
cd freeradius
cp .env.example .env
# Edit .env with your settings
```

Key variables in `.env`:

| Variable | Description | Example |
|----------|-------------|---------|
| `RADIUS_DOMAIN` | RADIUS server hostname | `radius.tsengsyu.com` |
| `CERTBOT_CERT_NAME` | Certificate directory name in certbot | `ldap.tsengsyu.com` |
| `EXTERNAL_CERTBOT_CONTAINER` | Certbot container name | `certbot` |
| `TEST_USER_PASSWORD` | Password for test user | `testpass123` |
| `GUEST_USER_PASSWORD` | Password for guest user | `guestpass123` |
| `ADMIN_USER_PASSWORD` | Password for admin user | `adminpass123` |
| `CONTRACTOR_PASSWORD` | Password for contractor user | `contractorpass123` |
| `VIP_PASSWORD` | Password for vip user | `vippass123` |

### Step 2: Deploy

```bash
make init
```

This runs: copy-certs → build → deploy → test

Or step by step:

```bash
make copy-certs    # Copy certificates from certbot
make build         # Build Docker image
make deploy        # Start service
make test          # Test authentication
```

## Test Users

| Username | Password Variable | Description |
|----------|-------------------|-------------|
| `test` | `TEST_USER_PASSWORD` | Basic testing |
| `guest` | `GUEST_USER_PASSWORD` | Limited access (1hr session) |
| `admin` | `ADMIN_USER_PASSWORD` | Full access |
| `contractor` | `CONTRACTOR_PASSWORD` | Time-limited (8hr session) |
| `vip` | `VIP_PASSWORD` | Priority access |

## Testing

```bash
# Test single user
make test

# Test all users
make test-users

# Manual test
docker exec freeradius-server /opt/bin/radtest test testpass123 localhost 0 testing123
```

Expected output:
```
Sent Access-Request Id 222 from 0.0.0.0:82a8 to 127.0.0.1:1812 length 74
Received Access-Accept Id 222 from 127.0.0.1:714 to 127.0.0.1:33448 length 37
    Reply-Message = "Hello test user"
```

## Management Commands

| Command | Description |
|---------|-------------|
| `make init` | Full setup: copy-certs → build → deploy → test |
| `make copy-certs` | Copy certificates from certbot |
| `make build` | Build Docker image |
| `make deploy` | Start service |
| `make stop` | Stop service |
| `make restart` | Restart service |
| `make logs` | View logs |
| `make logs-follow` | Follow logs in real-time |
| `make test` | Test basic authentication |
| `make test-users` | Test all configured users |
| `make clean` | Remove containers and volumes |
| `make status` | Show service status |

## How It Works

### Container Startup Flow

1. **Entrypoint** (`entrypoint.sh`):
   - Checks TLS certificates exist and are valid
   - Runs `setup-tls.sh` to configure EAP with Let's Encrypt certs
   - Replaces password placeholders in users file
   - Starts `radiusd -X` (debug mode)

2. **TLS Setup** (`setup-tls.sh`):
   - Updates EAP config to use `cert.pem`, `privkey.pem`, `fullchain.pem`
   - Sets proper file permissions

### Certificate Flow

```
Certbot Container                    FreeRADIUS Build
/etc/letsencrypt/live/              ./docker/freeradius/certs/
└── ldap.tsengsyu.com/    ──copy──▶ ├── cert.pem
    ├── cert.pem                    ├── privkey.pem
    └── fullchain.pem               └── fullchain.pem
                                            │
                                            ▼ (docker build)
                                    Container: /etc/raddb/certs/
```

### Debug Logging

FreeRADIUS runs with `-X` flag by default, showing detailed logs:

```bash
# View logs
docker compose logs -f

# Example output for authentication:
(0) Received Access-Request Id 42 from 127.0.0.1:36207 to 127.0.0.1:1812 length 74
(0)   User-Name = "test"
(0)   NAS-IP-Address = 172.18.0.2
(0)   NAS-Port = 0
(0) pap: User authenticated successfully
(0) Sent Access-Accept Id 42 from 127.0.0.1:1812 to 127.0.0.1:36207 length 37
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 1812 | UDP | RADIUS Authentication |
| 1813 | UDP | RADIUS Accounting |
| 2083 | TCP | RADIUS over TLS (RadSec) |

## Troubleshooting

### Container keeps restarting

```bash
docker compose logs --tail=50
```

Common issues:
- Certificate mismatch (private key doesn't match cert)
- Invalid users file syntax
- Missing certificate files

### Authentication fails

```bash
# Check user exists
docker exec freeradius-server cat /etc/raddb/mods-config/files/authorize

# Test with specific user
docker exec freeradius-server /opt/bin/radtest <user> <pass> localhost 0 testing123
```

### Certificates not found

```bash
# Verify certbot has certificates
docker exec certbot ls -la /etc/letsencrypt/live/

# Re-copy and rebuild
make copy-certs
make build
make deploy
```
