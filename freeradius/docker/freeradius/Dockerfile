# FreeRADIUS Server with TLS and SQL Support
FROM freeradius/freeradius-server:3.2.3-alpine

LABEL maintainer="LDAP WiFi Auth Team"
LABEL description="FreeRADIUS Server with TLS certificates and SQL logging"
LABEL version="1.1.0"

# Install additional tools
USER root
RUN apk add --no-cache \
    bash \
    curl \
    openssl \
    postgresql-client \
    && rm -rf /var/cache/apk/*

# Create directories for scripts and logs
RUN mkdir -p /opt/radius-scripts \
    && mkdir -p /var/log/freeradius

# Copy configuration files (Alpine uses /etc/raddb)
COPY config/radiusd.conf /etc/raddb/radiusd.conf
COPY config/clients.conf /etc/raddb/clients.conf

# Copy SQL module configuration
COPY config/sql/sql /etc/raddb/mods-available/sql
COPY config/sql/queries.conf /etc/raddb/mods-config/sql/queries.conf

# Copy server certificates (Let's Encrypt)
COPY certs/server/*.pem /etc/raddb/certs/server/

# Copy client CA certificates (Private CA for EAP-TLS client verification)
COPY certs/ca/*.pem /etc/raddb/certs/ca/

# Copy test users (overwrites authorize file)
COPY users/users /etc/raddb/mods-config/files/authorize

# Copy custom scripts
COPY entrypoint.sh /opt/radius-scripts/entrypoint.sh
COPY setup-tls.sh /opt/radius-scripts/setup-tls.sh

# Make scripts executable
RUN chmod +x /opt/radius-scripts/*.sh

# Set proper permissions for certificates
RUN chmod 600 /etc/raddb/certs/server/*.pem || true \
    && chmod 644 /etc/raddb/certs/server/cert.pem /etc/raddb/certs/server/fullchain.pem || true \
    && chmod 644 /etc/raddb/certs/ca/*.pem || true

# Custom entrypoint
ENTRYPOINT ["/opt/radius-scripts/entrypoint.sh"]

# Default command - foreground mode for production
CMD ["/opt/sbin/radiusd", "-f"]
