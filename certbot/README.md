# certbot — shared certificate foundation

> Part of the [Enterprise Authentication Testing Platform](../README.md). This is the one
> service every other service depends on: it acquires the TLS certificate they all share.

## What it is

A minimal certbot container that acquires **one multi-domain (SAN) certificate** from
Let's Encrypt and keeps it renewed in a Docker volume. The sibling services
(`ldap`, `freeradius`, `keycloak`, `mail`, `mcp-radius-sql`) don't each talk to Let's
Encrypt — they copy this certificate into their own build with `make copy-certs`. Deploy
certbot **first**; nothing else can build TLS until the certificate exists.

It uses the **DNS-01 challenge via Cloudflare**, so no inbound port (80/443) is needed —
validation happens through your DNS, which is why this works for services that never
expose HTTP.

## Quickstart

```bash
make env          # create .env, then edit DOMAINS / LETSENCRYPT_EMAIL / STAGING
# create cloudflare.ini next to this README (see Configuration) with your API token
make deploy       # acquire the SAN certificate, then renew every 12h
make logs         # watch for "Successfully received certificate"
```

`make` targets: `env`, `deploy`, `stop`, `logs`, `clean`. **`clean` removes the volume —
it deletes the certificate.**

Once issued, each sibling service copies the certificate from the running container:

```bash
cd ../ldap && make copy-certs   # docker cp out of the certbot container
```

## Configuration

`.env` (from `.env.example`):

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOMAINS` | `ldap.example.com,radius.example.com` | Comma-separated names on the SAN certificate |
| `LETSENCRYPT_EMAIL` | `admin@example.com` | Account / expiry-notice email |
| `STAGING` | `true` | `true` = Let's Encrypt **staging** (untrusted test certs, high rate limit). Set `false` for real certificates. |
| `DRY_RUN` | `false` | `true` = simulate issuance (validate Cloudflare creds + DNS without issuing) |

**`cloudflare.ini`** — you create it (not checked in); mounted read-only at
`/etc/cloudflare/cloudflare.ini`. Use a Cloudflare API token scoped to **Zone › DNS ›
Edit** for your domain:

```ini
dns_cloudflare_api_token = <your-cloudflare-api-token>
```

## How it works

- **Acquisition:** `certbot certonly --dns-cloudflare` creates an `_acme-challenge` TXT
  record via the Cloudflare API, waits 30s for propagation, and Let's Encrypt validates it.
- **Storage:** certificates land in the `certificates` Docker volume at
  `/etc/letsencrypt/live/<first-domain>/` (`fullchain.pem`, `privkey.pem`, `cert.pem`, `chain.pem`).
- **Renewal:** the container loops `certbot renew` every 12 hours. Let's Encrypt only
  re-issues within 30 days of expiry, so most runs are no-ops.

After a renewal, each service must re-copy and rebuild to pick up the new certificate — see
the [root README](../README.md) and [architecture notes](../docs/03-ARCHITECTURE.md).

## Files

- [`docker-compose.yml`](docker-compose.yml) — the certbot service and the `certificates` volume
- [`Makefile`](Makefile) — the targets above
- [`.env.example`](.env.example) — configuration template
