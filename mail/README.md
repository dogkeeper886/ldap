# Mail Server (Receive Only)

Receive-only mail server for guest credential delivery and testing.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│    Certbot      │────▶│   Mail Server   │
│  (certificates) │     │ (Postfix/IMAP)  │
└─────────────────┘     └─────────────────┘
        │                       │
        ▼                       ▼
  ldap.example.com        Ports: 25 (SMTP)
  (SAN certificate)              993 (IMAPS)
```

## Prerequisites

- Certbot container running with certificates
- Docker and Docker Compose v2

## Directory Structure

```
mail/
├── .env                    # Environment configuration
├── .env.example            # Template for .env
├── docker-compose.yml      # Docker service definition
├── Makefile                # Management commands
├── config/                 # Mail server configuration
├── docker/
│   └── certs/              # TLS certificates (copied at build)
└── scripts/
    ├── copy-certs.sh       # Copy certs from certbot
    └── read-guest-mail.sh  # Read guest credential emails
```

## Setup

### Step 1: Configure Environment

```bash
cd mail
make env
# Edit .env with your settings
```

Key variables in `.env`:

| Variable | Description | Example |
|----------|-------------|---------|
| `MAIL_DOMAIN` | Mail server hostname | `mail.example.com` |
| `PRIMARY_CERT_DOMAIN` | Certificate domain in certbot | `ldap.example.com` |
| `POSTMASTER_ADDRESS` | Postmaster email | `postmaster@mail.example.com` |
| `MAIL_USER` | Default mail user for reading | `guest` |

### Step 2: Deploy

```bash
make deploy
```

This copies certificates and starts the mail server.

## Management Commands

| Command | Description |
|---------|-------------|
| `make deploy` | Start mail server |
| `make stop` | Stop mail server |
| `make logs` | View logs |
| `make clean` | Remove containers and volumes |

### User Management

| Command | Description |
|---------|-------------|
| `make add-user` | Add a mail user (interactive) |
| `make del-user` | Delete a mail user (interactive) |
| `make update-password` | Update user password (interactive) |
| `make list-users` | List mail users |

### Guest Mail

| Command | Description |
|---------|-------------|
| `make read-guest-mail` | Read guest credential emails |
| `make clean-mail` | Delete all mail |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 25 | SMTP | Receive incoming mail |
| 993 | IMAPS | Secure mail retrieval |

## Features

- Receive-only configuration (no relay)
- TLS encryption with Let's Encrypt certificates
- IMAP access for mail retrieval
- No spam filtering (ClamAV, SpamAssassin disabled)
- Minimal footprint for testing purposes

## Use Cases

1. **Guest credential delivery** - Send WiFi credentials to guest email
2. **Testing email notifications** - Receive system alerts
3. **Credential verification** - Confirm user registration emails

## Troubleshooting

### Mail not receiving

```bash
# Check mail server logs
make logs

# Verify mail server is running
docker ps | grep mailserver
```

### Certificate errors

```bash
# Re-copy certificates from certbot
make copy-certs
make stop && make deploy
```

### Cannot read mail

```bash
# Verify mail user exists
make list-users

# Check mail directory
docker exec mailserver ls -la /var/mail/
```
