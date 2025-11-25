# FreeRADIUS Server with TLS Support
FROM freeradius/freeradius-server:3.2.3-alpine

LABEL maintainer="LDAP WiFi Auth Team"
LABEL description="FreeRADIUS Server with TLS certificates for WiFi authentication"
LABEL version="1.0.0"

# Install additional tools
USER root
RUN apk add --no-cache \
    bash \
    curl \
    openssl \
    && rm -rf /var/cache/apk/*

# Create directories for scripts and logs
RUN mkdir -p /opt/radius-scripts \
    && mkdir -p /var/log/freeradius

# Copy configuration files (Alpine uses /etc/raddb)
COPY config/radiusd.conf /etc/raddb/radiusd.conf
COPY config/clients.conf /etc/raddb/clients.conf

# Copy certificates to container
COPY certs/*.pem /etc/raddb/certs/

# Copy test users (overwrites authorize file)
COPY users/users /etc/raddb/mods-config/files/authorize

# Copy custom scripts
COPY entrypoint.sh /opt/radius-scripts/entrypoint.sh
COPY setup-tls.sh /opt/radius-scripts/setup-tls.sh

# Make scripts executable
RUN chmod +x /opt/radius-scripts/*.sh

# Set proper permissions for certificates
RUN chmod 600 /etc/raddb/certs/*.pem || true \
    && chmod 644 /etc/raddb/certs/cert.pem /etc/raddb/certs/fullchain.pem || true

# Custom entrypoint
ENTRYPOINT ["/opt/radius-scripts/entrypoint.sh"]

# Default command - debug mode (-X) for detailed logging
CMD ["/opt/sbin/radiusd", "-X"]
