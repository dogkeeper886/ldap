# mail — receive-only mail server

> Part of the [Enterprise Authentication Testing Platform](../README.md). A throwaway inbox
> for verifying the credential emails an onboarding flow sends — without a real mail provider.

## What it is

A `docker-mailserver` (Postfix + Dovecot) configured to **receive only** — no relay, no
outbound. It accepts mail on SMTP (25) and serves it over IMAPS (993), so a test can send a
guest a WiFi password and you can read it back to confirm delivery. Spam/AV scanning
(ClamAV, SpamAssassin, Fail2Ban) is disabled and **SMTP requires no authentication** — fine
for a closed test platform, not for exposure to the internet.

## Quickstart

```bash
make deploy           # copy the cert from certbot, then start the server
make add-user         # create a mailbox (interactive)
make read-guest-mail  # extract the WiFi name + password from a guest email
```

> Requires the `certbot` service running first (for the TLS certificate).

`make` targets: `deploy`, `stop`, `logs`, `clean`, `copy-certs`, and mailbox management —
`add-user`, `del-user`, `update-password`, `list-users`, `read-guest-mail`, `clean-mail`.

## Configuration

`.env` (from `.env.example`):

| Variable | Purpose |
|----------|---------|
| `MAIL_DOMAIN` | Mail hostname and mailbox path root |
| `PRIMARY_CERT_DOMAIN` | Which certbot certificate to copy (e.g. `ldap.example.com`) |
| `POSTMASTER_ADDRESS` | Postmaster contact address |
| `MAIL_USER` | Default mailbox for `read-guest-mail` / `clean-mail` |

The certificate is copied from certbot **at deploy time** (`SSL_TYPE=manual`); there is no
build step. To fan many guest addresses into one mailbox, see
[`config/postfix-virtual.cf.example`](config/postfix-virtual.cf.example).

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 25 | SMTP | Receive incoming mail |
| 993 | IMAPS | Secure retrieval (TLS) |

## Certificates

`make deploy` runs `copy-certs`, pulling `fullchain.pem` and `privkey.pem` out of the
certbot container into `docker/certs/`, which docker-compose **mounts read-only at runtime**
(`/tmp/ssl`, `SSL_TYPE=manual`) — no build step. After a renewal, re-run
`make copy-certs && make stop && make deploy`. `PRIMARY_CERT_DOMAIN` must match certbot's
live-directory name (default `ldap.example.com`).

## Files

- [`scripts/read-guest-mail.sh`](scripts/read-guest-mail.sh) — parse WiFi credentials from a guest email
- [`config/postfix-virtual.cf.example`](config/postfix-virtual.cf.example) — guest-address forwarding template
- [`Makefile`](Makefile) · [`.env.example`](.env.example) · [`docker-compose.yml`](docker-compose.yml)
