# mail — receive-only credential inbox

> Part of the [Enterprise Authentication Testing Platform](../README.md). A throwaway inbox
> for verifying the credential emails an onboarding flow sends — without a real mail provider.

## What it is

A `docker-mailserver` (Postfix + Dovecot) configured to **receive only** — it accepts mail
on SMTP (25), stores it in a Maildir, and serves it over IMAPS (993). There is **no relay,
no outbound, and no SMTP authentication**, and spam/AV scanning (ClamAV, SpamAssassin,
Fail2Ban, Postgrey) is off. That posture is fine for a closed test platform and unsafe to
expose to the internet. A test sends a guest a WiFi password; you read it back to confirm
delivery.

## How it works

![Receive a credential email, read it back: a test workflow delivers over SMTP :25 to docker-mailserver (receive-only, no relay/auth, scanning off); a tester retrieves over IMAPS :993 or with make read-guest-mail; the TLS cert is mounted read-only from certbot](docs/images/mail-flow.png)

Mail lands in the Maildir at `/var/mail/<MAIL_DOMAIN>/<MAIL_USER>/new/`. You can read it
over IMAPS, or run `make read-guest-mail`, which parses the **WiFi network name and
password out of the email's HTML** — purpose-built for verifying guest-credential delivery.

## Quickstart

```bash
make deploy            # copy the cert from certbot, then start the server
make add-user          # create a mailbox (interactive)
make read-guest-mail   # print the WiFi name + password from the newest emails
```

> Requires the `certbot` service running first (for the TLS certificate).

## Mailbox management

Thin wrappers over docker-mailserver's `setup email` command:

| Target | Action |
|--------|--------|
| `add-user` / `del-user` | Add / remove a mailbox (interactive) |
| `update-password` | Change a mailbox password (interactive) |
| `list-users` | List mailboxes |
| `read-guest-mail` | Extract WiFi credentials from `MAIL_USER`'s inbox |
| `clean-mail` | Empty `MAIL_USER`'s `new/` and `cur/` folders |

Lifecycle: `deploy`, `stop`, `logs`, `clean` (`down -v` — removes the mailbox volumes).

## Configuration

`.env` (from `.env.example`):

| Variable | Purpose |
|----------|---------|
| `MAIL_DOMAIN` | Mail hostname and Maildir path root |
| `PRIMARY_CERT_DOMAIN` | Which certbot certificate to copy (e.g. `ldap.example.com`) |
| `POSTMASTER_ADDRESS` | Postmaster contact address |
| `MAIL_USER` | Default mailbox for `read-guest-mail` / `clean-mail` |

To fan many guest addresses into one mailbox, see
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
