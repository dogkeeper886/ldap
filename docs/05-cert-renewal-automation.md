# Certificate Renewal Automation (Deploy Hook)

## Problem Statement

The TLS certificate served by FreeRADIUS expired in production even though
certbot was configured to renew it. Two gaps caused this:

1. **Certs are baked into the image at build time.** `freeradius/Dockerfile`
   `COPY`s `certs/server/*.pem` into the image. A renewed certificate sitting in
   the certbot volume never reaches the running container until someone manually
   runs `make copy-certs && docker compose up -d --build freeradius`.
2. **No propagation step fires on renewal.** Certbot's renewal loop
   (`certbot renew` every 12h) only rewrites files inside its own volume — there
   was no `--deploy-hook`, so nothing copied the new cert out or restarted the
   dependent services.

Net effect: certbot renewed the cert in its volume, FreeRADIUS kept serving the
old baked-in copy, and the served cert eventually expired.

## Proposed Solution

Add a certbot **`--deploy-hook`** that runs only when a certificate is actually
renewed. The hook copies the renewed cert into every service that uses the shared
SAN cert and refreshes each one, so no service keeps serving the old cert.

For the three services that bake the cert into their image we keep that model
(deploy-hook + rebuild) rather than switching to a runtime mount, to minimise the
change to those images and their TLS setup; the two that already mount the cert
at runtime are simply recreated to reload it.

```
certbot renew  --(cert changed)-->  deploy-hook.sh
   1. copy renewed cert.pem / privkey.pem / fullchain.pem into every
      service's cert dir (freeradius, mcp-radius-sql, ldap, keycloak, mail)
   2. baked-in certs  -> docker compose up -d --build  (freeradius+mcp, ldap)
      mounted certs    -> docker compose up -d --force-recreate (keycloak, mail)
```

The same SAN certificate is used by all five services, so the hook propagates
to all of them. How each picks up the new cert depends on how it consumes it:

| Service | Cert delivery | Refresh action |
|---------|---------------|----------------|
| freeradius | baked (image COPY) | rebuild + recreate |
| mcp-radius-sql | baked (image COPY) | rebuild + recreate |
| ldap | baked (image COPY) | rebuild + recreate |
| keycloak | runtime bind mount | force-recreate (reload) |
| mail | runtime bind mount | force-recreate (reload) |

Per-service deploy steps are best-effort: a failure for one service is logged
and does not block propagation to the others.

## Key Decisions

- **Deploy-hook, not a host cron.** The hook fires on the actual renewal event
  (certbot only runs `--deploy-hook` when the lineage changed), so there is no
  polling and no rebuild when nothing changed.
- **certbot container drives the rebuild.** The hook runs inside the certbot
  container, which is given (a) the host Docker socket and (b) the repository
  mounted read-write, so it can copy certs into the build context and invoke
  `docker compose --build` against the host daemon.
- **docker CLI added via a thin image.** `certbot/Dockerfile` extends
  `certbot/dns-cloudflare` with `apk add docker-cli docker-cli-compose`. This is
  built once, not installed on every renewal.
- **All five services.** The shared SAN cert is used by freeradius, mcp-radius-sql,
  ldap, keycloak and mail. The hook propagates to all of them — rebuilding the
  three that bake certs into their image and force-recreating the two that mount
  certs at runtime — so no service can silently keep serving an expired cert.
- **Only FreeRADIUS needed a chain fix.** Verified that ldap/keycloak/mail/mcp
  already present a complete chain; FreeRADIUS was the only one sending a
  leaf-only cert (its EAP module sends only `certificate_file`). That fix
  (`cert.pem` → `fullchain.pem`) is separate from this renewal automation.

## Security Note

Mounting `/var/run/docker.sock` into the certbot container grants it
root-equivalent control of the host Docker daemon. This is an accepted tradeoff
for the deploy-hook approach. The socket is only used by the deploy-hook to
rebuild/recreate dependent services. If this tradeoff is unacceptable, switch to
the runtime-mount approach (mount certs read-only into FreeRADIUS and reload on
renewal) which does not need the socket.

## Operational Notes

- The certbot service must be **running** for renewals (and therefore the hook)
  to fire. It is a long-running container (`certbot renew` loop) — keep it up.
- `CERTBOT_CERT_NAME` must match the certbot **lineage name**, which is the first
  domain in `DOMAINS` (e.g. `ldap.tsengsyu.com`), not necessarily the RADIUS
  domain. The hook relies on certbot's `$RENEWED_LINEAGE`, so it is correct
  automatically on renewal; the variable only matters for the manual
  `copy-certs-for-build.sh` path.
- To test without waiting for a real renewal: `docker exec certbot certbot renew
  --force-renewal` (against staging first), or run the hook script directly.
