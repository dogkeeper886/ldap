# Certbot Container with Custom Certificate Management
FROM certbot/certbot:v2.7.4

LABEL maintainer="LDAP WiFi Auth Team"
LABEL description="Certbot with custom certificate management for LDAP server"
LABEL version="1.0.0"

# Install additional tools
USER root
RUN apk add --no-cache     bash     curl     netcat-openbsd     openssl     docker-cli     jq     python3     && rm -rf /var/cache/apk/*

# Create directories for custom scripts and certbot
RUN mkdir -p /opt/certbot-scripts     && mkdir -p /opt/certbot-config     && mkdir -p /opt/certbot-logs     && mkdir -p /var/log/letsencrypt     && mkdir -p /var/lib/letsencrypt     && mkdir -p /etc/letsencrypt

# Copy custom scripts
COPY entrypoint.sh /opt/certbot-scripts/entrypoint.sh
COPY renew-certificates.sh /opt/certbot-scripts/renew-certificates.sh
COPY hook-post-renew.sh /opt/certbot-scripts/hook-post-renew.sh

# Make scripts executable
RUN chmod +x /opt/certbot-scripts/*.sh

# Create certbot user (if not exists) and set permissions
RUN addgroup -g 1000 certbot || true
RUN adduser -u 1000 -G certbot -s /bin/bash -D certbot || true

# Set ownership for all certbot directories
RUN chown -R certbot:certbot /opt/certbot-logs     && chown -R certbot:certbot /opt/certbot-scripts     && chown -R certbot:certbot /var/log/letsencrypt     && chown -R certbot:certbot /var/lib/letsencrypt     && chown -R certbot:certbot /etc/letsencrypt

# Create log file
RUN touch /opt/certbot-logs/certbot.log     && chown certbot:certbot /opt/certbot-logs/certbot.log


# Stay as root for permission management
# The entrypoint will run certbot commands with proper user
USER root

# Set custom entrypoint
ENTRYPOINT ["/opt/certbot-scripts/entrypoint.sh"]

# Default command (renewal loop)
CMD ["renew-loop"]
