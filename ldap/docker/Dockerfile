FROM osixia/openldap:1.5.0

USER root
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    apt-get update && apt-get install -y \
    ldap-utils \
    openssl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN mkdir -p /opt/ldap-scripts

COPY entrypoint.sh /opt/ldap-scripts/entrypoint.sh
COPY init-ldap.sh /opt/ldap-scripts/init-ldap.sh

RUN chmod +x /opt/ldap-scripts/*.sh

USER 911

ENTRYPOINT ["/opt/ldap-scripts/entrypoint.sh"]
CMD ["slapd", "-h", "ldap:/// ldaps:///", "-u", "openldap", "-g", "openldap", "-d", "256"]
