# Simple Certbot - Let's Encrypt Certificates

Minimal Docker-based Let's Encrypt certificate management using the official certbot image.

## User Flow

```
Step 1: Initial Certificate Request
┌──────┐    ┌─────────┐    ┌──────────────┐
│ User │───►│ Certbot │───►│ Let's Encrypt│
│      │    │ (:80)   │    │   (ACME)     │
└──────┘    └─────────┘    └──────────────┘
 make           │                 │
 deploy         ▼                 ▼
          ┌───────────┐    ┌───────────┐
          │ HTTP-01   │◄───│ Challenge │
          │ Challenge │    │ Verified  │
          └───────────┘    └───────────┘
                                 │
                                 ▼
                          ┌───────────┐
                          │ Certs     │
                          │ Issued    │
                          └───────────┘

Step 2: Other Services Extract Certificates
┌───────────┐    ┌─────────┐    ┌───────────────┐
│ ldap/     │───►│ docker  │───►│ certbot       │
│ freeradius│    │ exec    │    │ container     │
│ keycloak/ │    └─────────┘    └───────────────┘
│ mail      │                          │
└───────────┘                          ▼
     │                          ┌───────────┐
     │                          │ cert.pem  │
     │                          │ privkey   │
     │                          │ fullchain │
     ▼                          └───────────┘
┌───────────┐                          │
│ Service   │◄─────────────────────────┘
│ TLS Ready │
└───────────┘

Step 3: Automatic Renewal (every 12 hours)
┌─────────┐    ┌──────────────┐
│ Certbot │───►│ Let's Encrypt│
│ (loop)  │    │   (renew)    │
└─────────┘    └──────────────┘
                      │
                      ▼
               ┌────────────┐
               │ Certs      │
               │ Refreshed  │
               │ (if <30d)  │
               └────────────┘
```

## Prerequisites

- Port 80 must be available (not used by other services)
- Domain DNS must point to this server

## Quick Start

```bash
# Create .env file
make env

# Edit .env with your domains and email
DOMAINS=ldap.example.com,radius.example.com
LETSENCRYPT_EMAIL=admin@example.com
STAGING=true

# Deploy
make deploy
```

## Commands

- `make deploy` - Start certbot service
- `make stop` - Stop certbot service  
- `make logs` - View logs
- `make clean` - Remove containers and certificates

## Configuration (.env)

```bash
DOMAINS=ldap.example.com,radius.example.com
LETSENCRYPT_EMAIL=admin@example.com
STAGING=false     # Set to "true" for Let's Encrypt staging
DRY_RUN=false     # Set to "true" for testing without issuing certs
```

## Certificate Access

Certificates are stored in the `certificates` Docker volume. The certificate directory uses the first domain in `DOMAINS` list.

Other services in this repo extract certificates using their `copy-certs-for-build.sh` scripts:

```bash
# Example: Extract certificates (used by ldap, freeradius, keycloak, mail)
PRIMARY_DOMAIN="ldap.example.com"
docker exec certbot cat /etc/letsencrypt/live/${PRIMARY_DOMAIN}/cert.pem > ./cert.pem
docker exec certbot cat /etc/letsencrypt/live/${PRIMARY_DOMAIN}/privkey.pem > ./privkey.pem
docker exec certbot cat /etc/letsencrypt/live/${PRIMARY_DOMAIN}/fullchain.pem > ./fullchain.pem
```

## Notes

- Certificates renew automatically 30 days before expiration
- Uses official `certbot/certbot` Docker image
- Fails fast - no complex error handling or health checks
- For production, set `STAGING=false` in .env