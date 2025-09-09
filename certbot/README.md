# Simple Certbot - Let's Encrypt Certificates

Minimal Docker-based Let's Encrypt certificate management using the official certbot image.

## What It Does

- Acquires SSL/TLS certificates from Let's Encrypt
- Handles automatic renewals every 12 hours
- Supports multiple domains with SAN certificates
- Uses standalone HTTP challenge on port 80

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
STAGING=true      # Use false for production
DRY_RUN=false     # Use true for testing
```

## Certificate Access

Certificates are stored in the `certificates` Docker volume. Access them from other containers:

```bash
# Copy certificates from running container
docker cp standalone-certbot:/etc/letsencrypt/live/your-domain/cert.pem ./
docker cp standalone-certbot:/etc/letsencrypt/live/your-domain/privkey.pem ./
docker cp standalone-certbot:/etc/letsencrypt/live/your-domain/fullchain.pem ./
```

## Notes

- Certificates renew automatically 30 days before expiration
- Uses official `certbot/certbot` Docker image
- Fails fast - no complex error handling or health checks
- For production, set `STAGING=false` in .env