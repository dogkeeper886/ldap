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

# Create directories for certificates and custom configuration
RUN mkdir -p /etc/freeradius/3.0/certs \
    && mkdir -p /opt/radius-scripts \
    && mkdir -p /var/log/freeradius

# Copy certificates to container (build-time)
COPY certs/*.pem /etc/freeradius/3.0/certs/ 

# Copy custom configuration files
COPY config/radiusd.conf /etc/freeradius/3.0/
COPY config/clients.conf /etc/freeradius/3.0/
COPY config/authorize /etc/freeradius/3.0/mods-config/files/
COPY config/eap /etc/freeradius/3.0/mods-available/

# Copy test users
COPY users/users /etc/freeradius/3.0/mods-config/files/

# Copy custom scripts
COPY entrypoint.sh /opt/radius-scripts/entrypoint.sh
COPY setup-tls.sh /opt/radius-scripts/setup-tls.sh

# Make scripts executable
RUN chmod +x /opt/radius-scripts/*.sh

# Set proper ownership and permissions
RUN chown -R freerad:freerad /etc/freeradius/3.0 \
    && chown -R freerad:freerad /var/log/freeradius \
    && chmod 600 /etc/freeradius/3.0/certs/*.pem || true \
    && chmod 644 /etc/freeradius/3.0/certs/cert.pem /etc/freeradius/3.0/certs/fullchain.pem || true

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD radtest test testpass123 localhost 0 testing123 || exit 1

# Switch to freerad user
USER freerad

# Custom entrypoint
ENTRYPOINT ["/opt/radius-scripts/entrypoint.sh"]

# Default command
CMD ["freeradius", "-f"]