# Feature List

Enterprise authentication testing platform with LDAP, RADIUS, SAML, and mail services.

## Current Features

### Certificate Management (certbot/)

| Feature | Status | Description |
|---------|--------|-------------|
| Let's Encrypt certificates | ✅ | Automated certificate acquisition |
| Multi-domain SAN | ✅ | Single cert covers multiple domains |
| Auto renewal | ✅ | Checks every 12 hours |
| Docker cp distribution | ✅ | Certificates copied to services at build |

### LDAP Server (ldap/)

| Feature | Status | Description |
|---------|--------|-------------|
| OpenLDAP with TLS | ✅ | Ports 389 (LDAP) and 636 (LDAPS) |
| Test users | ✅ | 5 users with different roles |
| AD compatibility | ✅ | Microsoft Active Directory attributes |
| Group-based access | ✅ | wifi-users, wifi-guests, wifi-admins, etc. |

### RADIUS Server (freeradius/)

| Feature | Status | Description |
|---------|--------|-------------|
| FreeRADIUS 3.x | ✅ | Enterprise RADIUS server |
| EAP-TLS | ✅ | Client certificate authentication |
| EAP-TTLS/PEAP | ✅ | Password-based EAP methods |
| RadSec (port 2083) | ✅ | RADIUS over TLS |
| PostgreSQL logging | ✅ | SQL auth and accounting tables |
| SQL query commands | ✅ | sql-auth, sql-acct, sql-by-mac, sql-detail |
| Debug mode | ✅ | Verbose logging with -X flag |
| Test users | ✅ | 5 users matching LDAP |

### SAML Identity Provider (keycloak/)

| Feature | Status | Description |
|---------|--------|-------------|
| Keycloak IdP | ✅ | SAML 2.0 Identity Provider |
| LDAP federation | ✅ | Users synced from OpenLDAP |
| TLS endpoints | ✅ | HTTPS on port 8443 |
| Realm configuration | ✅ | saml-test realm pre-configured |

### Mail Server (mail/)

| Feature | Status | Description |
|---------|--------|-------------|
| Receive-only | ✅ | No relay/outbound |
| IMAPS access | ✅ | Secure mail retrieval on port 993 |
| User management | ✅ | add-user, del-user, list-users |
| Guest mail reading | ✅ | Credential delivery verification |

## Development Sequence

### Phase 1: Core Infrastructure
- Standalone certbot for certificate management
- OpenLDAP with TLS and test users
- Basic FreeRADIUS with EAP support

### Phase 2: RADIUS SQL Logging
- PostgreSQL backend for FreeRADIUS
- radpostauth table for authentication logs
- radacct table for accounting sessions
- SQL query Makefile targets

### Phase 3: SAML Support
- Keycloak SAML 2.0 Identity Provider
- LDAP user federation
- TLS configuration with shared certificates

### Phase 4: Mail Server
- Receive-only mail server (Postfix/Dovecot)
- Guest credential delivery
- IMAPS access for verification

### Phase 5: EAP-TLS Enhancement
- Client certificate authentication
- Private CA support
- Debug mode for troubleshooting

## Future Considerations

| Feature | Priority | Notes |
|---------|----------|-------|
| Grafana monitoring | Low | See freeradius/docs/04-radius-monitor-stack.md |
| LDAP sync to RADIUS | Medium | Direct LDAP authentication |
| OAuth2/OIDC | Low | In addition to SAML |

## Documentation Map

```
docs/                           # Project-wide documentation
├── 01-brainstorming-session-results.md  # Initial planning
├── 02-PRD.md                            # Product requirements
├── 03-ARCHITECTURE.md                   # 5-project architecture
└── 04-FEATURES.md                       # This file

freeradius/docs/                # RADIUS-specific documentation
├── 01-allow-spaces-in-username.md
├── 02-radius-monitoring-research.md
├── 03-radius-sql-logging.md
├── 04-radius-monitor-stack.md
└── 05-mcp-radius-sql-server.md
```
