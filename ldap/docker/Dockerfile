# OpenLDAP Container with Custom Configuration
FROM osixia/openldap:1.5.0

LABEL maintainer="LDAP WiFi Auth Team"
LABEL description="OpenLDAP server for WiFi authentication testing"
LABEL version="1.0.0"

# Install additional tools
USER root
# Fix for Debian Buster EOL - use archive repositories
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list &&     echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list &&     apt-get update && apt-get install -y     curl     netcat     ldap-utils     openssl     && rm -rf /var/lib/apt/lists/*     && apt-get clean

# Create directories for custom scripts and configurations
RUN mkdir -p /opt/ldap-scripts     && mkdir -p /opt/ldap-config     && mkdir -p /opt/ldap-health     && mkdir -p /opt/ldap-certs     && chown 911:911 /opt/ldap-health     && chown 911:911 /opt/ldap-certs     && chmod 755 /opt/ldap-health     && chmod 755 /opt/ldap-certs

# Copy custom entrypoint and health check scripts
COPY entrypoint.sh /opt/ldap-scripts/entrypoint.sh
COPY health-check.sh /opt/ldap-scripts/health-check.sh
COPY init-ldap.sh /opt/ldap-scripts/init-ldap.sh
COPY download-certificates.sh /opt/ldap-scripts/download-certificates.sh

# Make scripts executable
RUN chmod +x /opt/ldap-scripts/*.sh

# Create custom LDAP configuration directory
VOLUME ["/opt/ldap-config"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3     CMD /opt/ldap-scripts/health-check.sh

# Switch back to LDAP user
USER 911

# Set custom entrypoint
ENTRYPOINT ["/opt/ldap-scripts/entrypoint.sh"]

# Default command
CMD ["slapd", "-h", "ldap:/// ldaps:///", "-u", "openldap", "-g", "openldap", "-d", "256"]
