# Certbot with Cloudflare DNS plugin + Docker CLI so the renewal deploy-hook
# can rebuild/redeploy dependent services against the host Docker daemon.
FROM certbot/dns-cloudflare

RUN apk add --no-cache docker-cli docker-cli-compose
