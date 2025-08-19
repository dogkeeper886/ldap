# LDAP TLS Certificate Bug Analysis & Solution Plan

**Date**: 2025-08-19  
**Status**: Critical Issue - TLS Negotiation Failures  
**Impact**: LDAPS connections failing, service degraded

## Executive Summary

After 4 failed attempts to enable TLS on our OpenLDAP server, we have identified the root cause: **architectural mismatch between certificate storage paths and OpenLDAP's expectations**, combined with **Docker volume permission conflicts**.

**Current State**: OpenLDAP stable but TLS disabled, causing LDAPS negotiation failures.

## Root Cause Analysis

### The Fundamental Problem

Our LDAP server exposes **port 636 (LDAPS)** but has **`LDAP_TLS=false`**, creating a configuration mismatch where clients expect TLS but the server doesn't provide it.

### Deep Technical Issues Identified

#### 1. Certificate Path Architecture Mismatch
- **Certbot Storage**: `/etc/letsencrypt/ldap-certs/` (managed by certbot container)
- **Environment Variables**: `ldap-certs/cert.pem` (relative path)
- **OpenLDAP Expectation**: `/container/service/slapd/assets/certs/` (absolute path)

#### 2. Docker Volume Permission Conflicts
- OpenLDAP startup script tries to `chown` certificate files
- Volume-mounted certificates cause permission denied errors
- Container cached state persists across configuration changes

#### 3. Container State Persistence
- Docker containers cache internal filesystem state
- Configuration changes don't clear cached certificate references
- Incremental fixes fail due to persistent state

## Previous Failed Attempts

### Attempt #1: Remove Read-Only Certificate Mount
```yaml
# REMOVED: - certificates:/container/service/slapd/assets/certs:ro
```
**Result**: FAILED - container still tried to chown entire certificate directory

### Attempt #2: Change Mount Path (Non Read-Only)
```yaml
# CHANGED TO: - certificates:/container/service/slapd/assets/certs
```
**Result**: FAILED - read-only filesystem errors persisted

### Attempt #3: Disable TLS Completely
```yaml
- LDAP_TLS=false
# REMOVED: All certificate volume mounts
```
**Result**: FAILED - cached container state persisted old certificate references

### Attempt #4: Complete Container Recreation
```bash
docker compose down && docker compose up -d
```
**Result**: ✅ SUCCESS - Container stable but **WITHOUT TLS**

## Current Architecture State

### Working Components ✅
- **GCP Infrastructure**: VM, DNS (ldap.tsengsyu.com), firewall rules
- **Let's Encrypt Certificates**: Valid until November 17, 2025
- **Certbot Container**: Auto-renewal every 12 hours
- **OpenLDAP Container**: Stable on ports 389/636 (TLS disabled)

### Failing Components ❌
- **LDAPS Connections**: TLS negotiation failures on port 636
- **Certificate Integration**: OpenLDAP cannot access certificates
- **TLS Configuration**: Disabled due to mounting issues

## Error Analysis

### Current TLS Negotiation Failure Logs
```
68a45676 conn=1010 fd=12 ACCEPT from IP=34.70.66.100:1024 (IP=0.0.0.0:636)
68a45676 conn=1010 fd=12 closed (TLS negotiation failure)
```

**Cause**: Port 636 requires TLS but `LDAP_TLS=false`

### Certificate Availability Verification
```bash
# Certificates exist in certbot container ✅
docker exec certbot ls -la /etc/letsencrypt/ldap-certs/
# -rw-r--r-- 1 root root 1298 cert.pem
# -rw-r--r-- 1 root root 2864 fullchain.pem
# -rw------- 1 root root  241 privkey.pem

# Certificates NOT accessible in OpenLDAP container ❌
docker exec openldap ls -la /etc/letsencrypt/ldap-certs/
# ls: cannot access '/etc/letsencrypt/ldap-certs/': No such file or directory
```

## Solution Strategy

### Approach: Certificate Copying Instead of Volume Mounting

**Why Copying vs Mounting**:
- Avoids permission conflicts from `chown` operations
- Allows proper file ownership within OpenLDAP container
- Eliminates read-only filesystem issues
- Provides clean certificate delivery mechanism

### Implementation Options

#### Option A: Init Container Approach
```yaml
services:
  cert-copier:
    image: alpine:latest
    volumes:
      - certificates:/source/certs:ro
      - ldap-certs:/target/certs
    command: |
      sh -c "
      cp /source/certs/ldap-certs/* /target/certs/ &&
      chown 911:911 /target/certs/* &&
      chmod 644 /target/certs/*
      "
    depends_on:
      - certbot
  
  openldap:
    volumes:
      - ldap-certs:/container/service/slapd/assets/certs
    environment:
      - LDAP_TLS=true
    depends_on:
      - cert-copier
```

#### Option B: Certbot Post-Renewal Enhancement
Modify certbot container to copy certificates directly to OpenLDAP's expected path:
```bash
# In certbot post-renewal hook
docker cp /etc/letsencrypt/ldap-certs/cert.pem openldap:/container/service/slapd/assets/certs/
docker cp /etc/letsencrypt/ldap-certs/privkey.pem openldap:/container/service/slapd/assets/certs/
docker cp /etc/letsencrypt/ldap-certs/fullchain.pem openldap:/container/service/slapd/assets/certs/
docker exec openldap chown openldap:openldap /container/service/slapd/assets/certs/*
docker exec openldap slapd-restart
```

#### Option C: Shared Volume with Proper Permissions
```yaml
volumes:
  ldap-certs:
    driver: local

services:
  certbot:
    # Copy certificates to shared volume with correct ownership
  
  openldap:
    volumes:
      - ldap-certs:/container/service/slapd/assets/certs
    environment:
      - LDAP_TLS=true
      - LDAP_TLS_CRT_FILENAME=cert.pem  # Absolute path now
      - LDAP_TLS_KEY_FILENAME=privkey.pem
      - LDAP_TLS_CA_CRT_FILENAME=fullchain.pem
```

## Recommended Implementation Plan

### Phase 1: Prepare Certificate Copying Infrastructure
1. Create dedicated volume for certificate sharing
2. Modify certbot to copy certificates with proper ownership
3. Test certificate accessibility without enabling TLS

### Phase 2: Enable TLS with Certificate Copying
1. Update docker-compose.yml with certificate copying mechanism
2. Set `LDAP_TLS=true` and `LDAP_TLS_ENFORCE=false` (for gradual rollout)
3. Update certificate path environment variables

### Phase 3: Testing & Validation
1. Test LDAPS connection: `openssl s_client -connect ldap.tsengsyu.com:636`
2. Verify certificate validity and chain
3. Test LDAP client connections with TLS
4. Monitor auto-renewal functionality

### Phase 4: Production Enablement
1. Set `LDAP_TLS_ENFORCE=true` for mandatory TLS
2. Update monitoring and alerting
3. Document operational procedures

## Risk Assessment

### Low Risk ✅
- Certificate validity (valid until Nov 17, 2025)
- Infrastructure stability (GCP, DNS, firewall)
- Basic LDAP functionality (port 389 working)

### Medium Risk ⚠️
- Container recreation may cause brief service interruption
- Certificate copying timing during renewals
- Client compatibility with TLS enforcement

### High Risk ❌
- Multiple failed attempts indicate complex issue
- Production service currently degraded (LDAPS non-functional)
- Let's Encrypt rate limiting if excessive certificate requests

## Success Criteria

### Technical Success
- [ ] LDAPS connections successful on port 636
- [ ] TLS certificate properly loaded by OpenLDAP
- [ ] No TLS negotiation failures in logs
- [ ] Certificate auto-renewal maintains TLS functionality

### Operational Success
- [ ] Client applications can connect via LDAPS
- [ ] Service monitoring shows healthy status
- [ ] Documentation updated with new architecture
- [ ] Rollback plan tested and documented

## Next Actions

1. **Select implementation approach** (recommend Option C - Shared Volume)
2. **Implement certificate copying mechanism**
3. **Test in staging/development environment**
4. **Gradual rollout with monitoring**
5. **Update operational documentation**

---

**Document Version**: 1.0  
**Last Updated**: 2025-08-19  
**Next Review**: After implementation completion