# Certbot Container with Custom Certificate Management
FROM certbot/certbot:v2.7.4

LABEL maintainer="LDAP WiFi Auth Team"
LABEL description="Certbot with custom certificate management for LDAP server"
LABEL version="1.0.0"

# Install additional tools
USER root
RUN apk add --no-cache \
    bash \
    curl \
    netcat-openbsd \
    openssl \
    docker-cli \
    jq \
    && rm -rf /var/cache/apk/*

# Create directories for custom scripts
RUN mkdir -p /opt/certbot-scripts \
    && mkdir -p /opt/certbot-config \
    && mkdir -p /opt/certbot-logs

# Copy custom scripts
COPY entrypoint.sh /opt/certbot-scripts/entrypoint.sh
COPY renew-certificates.sh /opt/certbot-scripts/renew-certificates.sh
COPY check-certificates.sh /opt/certbot-scripts/check-certificates.sh
COPY hook-post-renew.sh /opt/certbot-scripts/hook-post-renew.sh

# Make scripts executable
RUN chmod +x /opt/certbot-scripts/*.sh

# Create certbot user (if not exists)
RUN addgroup -g 1000 certbot || true
RUN adduser -u 1000 -G certbot -s /bin/bash -D certbot || true

# Create log file
RUN touch /opt/certbot-logs/certbot.log \
    && chown -R certbot:certbot /opt/certbot-logs \
    && chown -R certbot:certbot /opt/certbot-scripts

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD /opt/certbot-scripts/check-certificates.sh

# Switch to certbot user
USER certbot

# Set custom entrypoint
ENTRYPOINT ["/opt/certbot-scripts/entrypoint.sh"]

# Default command (renewal loop)
CMD ["renew-loop"]