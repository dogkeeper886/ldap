# FreeRADIUS Server

RADIUS authentication server with TLS/EAP support, featuring EAP-TLS client certificate authentication.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Certbot      │────▶│   FreeRADIUS    │◀────│  Private CA     │
│ (server certs)  │     │   (RADIUS)      │     │ (client certs)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        ▼                       ▼
  ldap.tsengsyu.com      Ports: 1812/udp (auth)
  radius.tsengsyu.com           1813/udp (acct)
  (SAN certificate)             2083/tcp (RadSec)
```

## Prerequisites

- Certbot container running with certificates for your RADIUS domain
- Docker and Docker Compose v2
- Private CA certificate for EAP-TLS client authentication (optional)

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
│   ├── certs/
│   │   ├── server/              # Server certificates (Let's Encrypt)
│   │   │   ├── cert.pem
│   │   │   ├── privkey.pem
│   │   │   └── fullchain.pem
│   │   └── ca/                  # Client CA (for EAP-TLS verification)
│   │       └── client-ca.pem
│   └── users/
│       └── users                # Test user definitions
└── scripts/
    ├── copy-certs-for-build.sh  # Copy certs from certbot
    ├── setup-users.sh           # Update user passwords
    └── test-all-users.sh        # Test all users
```

## EAP-TLS Authentication Flow

EAP-TLS provides mutual certificate-based authentication between clients and the RADIUS server.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         EAP-TLS Handshake                                │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   WiFi Client                              FreeRADIUS Server             │
│   (Supplicant)                                                           │
│                                                                          │
│   1. EAP-Identity ─────────────────────────────────────────────────────► │
│                                                                          │
│   ◄───────────────────────────────────────────────── 2. EAP-TLS Start    │
│                                                                          │
│   3. Client Hello ─────────────────────────────────────────────────────► │
│                                                                          │
│   ◄─────────────────────────────────── 4. Server Hello + Server Cert     │
│                                           (Let's Encrypt certificate)   │
│                                                                          │
│   5. Client verifies server cert                                         │
│      (using system trust store - Let's Encrypt is already trusted)      │
│                                                                          │
│   6. Client Cert ──────────────────────────────────────────────────────► │
│      (signed by Private CA)                                              │
│                                                                          │
│   7. Server verifies client cert ◄───────────────────────────────────    │
│      (using ca/client-ca.pem)                                            │
│                                                                          │
│   ◄───────────────────────────────────────────────── 8. EAP-Success      │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### Two Separate Trust Chains

| Direction | Certificate | Signed By | Verified By |
|-----------|-------------|-----------|-------------|
| Server → Client | `server/cert.pem` | Let's Encrypt | Client's OS trust store |
| Client → Server | Client certificate | Your Private CA | FreeRADIUS (`ca/client-ca.pem`) |

This separation allows:
- Clients to trust the server without extra configuration (Let's Encrypt is universally trusted)
- You to control which clients can authenticate (only those with certs signed by your CA)

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
| `CLIENT_CA_FILE` | Path to client CA certificate | `./wrca-root-*.crt` |
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
make copy-certs       # Copy server certificates from certbot
make copy-client-ca   # Copy client CA for EAP-TLS (if using certificate auth)
make build            # Build Docker image
make deploy           # Start service
make test             # Test authentication
```

### Step 3: Copy Client CA (for EAP-TLS)

If you have a private CA for client certificate authentication:

```bash
# Option 1: Using environment variable
make copy-client-ca CLIENT_CA_FILE=./wrca-root-98214785.tsengsyu.com.crt

# Option 2: Set in .env file, then run
make copy-client-ca
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
| `make copy-certs` | Copy server certificates from certbot |
| `make copy-client-ca` | Copy client CA for EAP-TLS verification |
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
   - Checks server certificates exist in `certs/server/`
   - Checks client CA exists in `certs/ca/`
   - Validates certificate expiration dates
   - Runs `setup-tls.sh` to configure permissions
   - Replaces password placeholders in users file
   - Starts `radiusd -f` (foreground mode)

2. **TLS Setup** (`setup-tls.sh`):
   - Sets proper file permissions on certificates
   - Server private key: 600 (owner read/write only)
   - Public certs and CA: 644 (world readable)

### Certificate Flow

```
Certbot Container                    FreeRADIUS Build
/etc/letsencrypt/live/              ./docker/freeradius/certs/
└── ldap.tsengsyu.com/    ──copy──▶ └── server/
    ├── cert.pem                        ├── cert.pem
    ├── privkey.pem                     ├── privkey.pem
    └── fullchain.pem                   └── fullchain.pem

Private CA File                     
./wrca-root-*.crt         ──copy──▶ └── ca/
                                        └── client-ca.pem
                                            │
                                            ▼ (docker build)
                                    Container: /etc/raddb/certs/
                                    ├── server/
                                    │   ├── cert.pem
                                    │   ├── privkey.pem
                                    │   └── fullchain.pem
                                    └── ca/
                                        └── client-ca.pem
```

### EAP Configuration

The EAP module (`config/eap`) is configured for EAP-TLS:

```
tls-config tls-common {
    # Server identity (Let's Encrypt)
    private_key_file = ${certdir}/server/privkey.pem
    certificate_file = ${certdir}/server/cert.pem
    
    # Client verification (Private CA)
    ca_file = ${certdir}/ca/client-ca.pem
    
    # Require client certificates
    require_client_cert = yes
    verify_depth = 2
    
    # TLS settings
    tls_min_version = "1.2"
    tls_max_version = "1.3"
}
```

### Debug Logging

View detailed authentication logs:

```bash
# View logs
docker compose logs -f

# Example EAP-TLS authentication output:
(0) Received Access-Request Id 42 from 127.0.0.1:36207 to 127.0.0.1:1812
(0)   User-Name = "device@example.com"
(0) eap: Peer sent EAP-Identity (type 1)
(0) eap: Calling submodule eap_tls
(0) eap_tls: (TLS) recv TLS 1.3 Handshake, ClientHello
(0) eap_tls: (TLS) send TLS 1.3 Handshake, ServerHello
(0) eap_tls: (TLS) send TLS 1.3 Handshake, Certificate
(0) eap_tls: (TLS) recv TLS 1.3 Handshake, Certificate
(0) eap_tls: (TLS) Validation succeeded for client certificate
(0) eap: Sending EAP-Success
(0) Sent Access-Accept Id 42
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

### EAP-TLS authentication fails

```bash
# Check certificates are in place
docker exec freeradius-server ls -la /etc/raddb/certs/server/
docker exec freeradius-server ls -la /etc/raddb/certs/ca/

# Verify client CA
docker exec freeradius-server openssl x509 -in /etc/raddb/certs/ca/client-ca.pem -text -noout

# Check if client cert is signed by correct CA
openssl verify -CAfile docker/freeradius/certs/ca/client-ca.pem client-cert.pem
```

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
make copy-client-ca
make build
make deploy
```

### Client certificate not trusted

Ensure the client certificate is signed by the CA in `certs/ca/client-ca.pem`:

```bash
# Check the issuer of your client certificate
openssl x509 -in client.crt -issuer -noout

# Should match the subject of your CA
openssl x509 -in docker/freeradius/certs/ca/client-ca.pem -subject -noout
```
