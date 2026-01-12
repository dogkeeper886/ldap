# Mail Server

Receive-only mail server for testing email delivery.

## User Flow

```
Step 1: Certificate Setup
┌─────────────────┐     ┌─────────────────┐
│    Certbot      │────▶│   Mail Server   │
│   (Port 80)     │     │  (deploy time)  │
└─────────────────┘     └─────────────────┘
        │                       │
        ▼                       ▼
   Let's Encrypt          certs copied to
   certificates           /tmp/ssl/

Step 2: Receive Email
┌──────────┐    ┌─────────────┐
│ External │───▶│ Mail Server │
│  Sender  │    │  (Port 25)  │
└──────────┘    └─────────────┘
                      │
                      ▼
                ┌───────────┐
                │ Email     │
                │ Received  │
                └───────────┘

Step 3: Read Email via IMAP
┌──────┐    ┌─────────────┐
│ User │───▶│ Mail Server │
└──────┘    │ (Port 993)  │
            └─────────────┘
                  │
                  ▼
            ┌───────────┐
            │ Email     │
            │ Retrieved │
            └───────────┘
```

## Prerequisites

- Certbot container running with certificates
- Docker and Docker Compose v2

## Quick Start

```bash
# 1. Create environment configuration
cp .env.example .env
# Edit .env with your settings

# 2. Deploy mail server
make deploy

# 3. Add a mail user
make add-user
```

## Configuration (.env)

| Variable | Description | Example |
|----------|-------------|---------|
| `MAIL_DOMAIN` | Mail server hostname | `mail.example.com` |
| `PRIMARY_CERT_DOMAIN` | Certificate directory in certbot | `ldap.example.com` |
| `POSTMASTER_ADDRESS` | Postmaster email address | `postmaster@mail.example.com` |
| `MAIL_USER` | Default mailbox user | `user` |

## Commands

| Command | Description |
|---------|-------------|
| `make deploy` | Start mail server |
| `make stop` | Stop mail server |
| `make logs` | View logs |
| `make clean` | Remove containers and volumes |
| `make copy-certs` | Copy certificates from certbot |

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
| 25 | SMTP | Receive email |
| 993 | IMAPS | Read email (TLS) |

## Notes

- Receive-only configuration (no outbound relay)
- No spam filtering or virus scanning (minimal footprint)
- Uses docker-mailserver image
