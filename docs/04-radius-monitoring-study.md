# RADIUS Monitoring Study

## Problem Statement

Three observability gaps exist in the current FreeRADIUS deployment:

| Issue | Current State | Impact |
|-------|---------------|--------|
| No NAS-Identifier visibility | Auth/accounting requests don't expose NAS-Identifier in queryable format | Cannot identify which access points are sending requests |
| Console debug logging | Running with `-X` flag outputs verbose debug to stdout | Not suitable for production; noisy and unstructured |
| No centralized log collection | Logs stay in container volumes | No dashboards, alerting, or historical analysis |

---

## Current Architecture

### FreeRADIUS Logging Configuration

**radiusd.conf settings:**
```
log {
    destination = files
    file = ${logdir}/radius.log
    auth = no              # Auth details NOT logged
    auth_badpass = no
    auth_goodpass = no
}
```

**Container startup:**
```bash
radiusd -X  # Debug mode - verbose stdout
```

**Accounting directory:**
```
/var/log/freeradius/radacct/
```

### What Gets Logged Today

Debug output (`-X` flag) shows:
```
(0) Received Access-Request Id 42 from 127.0.0.1:36207 to 127.0.0.1:1812 length 74
(0)   User-Name = "test"
(0)   NAS-IP-Address = 172.18.0.2
(0)   NAS-Port = 0
(0) pap: User authenticated successfully
(0) Sent Access-Accept Id 42 from 127.0.0.1:1812 to 127.0.0.1:36207 length 37
```

**Missing from structured logs:**
- `NAS-Identifier` (device hostname/name sent by NAS)
- `Called-Station-Id` (MAC of the access point)
- `Calling-Station-Id` (MAC of the client device)
- Session duration and bytes transferred (accounting)

---

## Proposed Solution

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MONITORING ARCHITECTURE                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  FreeRADIUS  │     │    Promtail  │     │     Loki     │
│              │────►│              │────►│              │
│  linelog     │     │  (shipper)   │     │  (storage)   │
│  module      │     └──────────────┘     └──────────────┘
└──────────────┘                                │
      │                                         │
      │ Structured logs                         │
      │ - NAS-Identifier                        ▼
      │ - NAS-IP-Address                  ┌──────────────┐
      │ - User-Name                       │   Grafana    │
      │ - Auth result                     │              │
      │ - Acct-Status-Type                │  Dashboards  │
      ▼                                   └──────────────┘
┌──────────────┐
│ /var/log/    │
│ freeradius/  │
│ linelog/     │
└──────────────┘
```

### Component Responsibilities

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **linelog module** | Write structured auth/accounting logs | New FreeRADIUS config |
| **Promtail** | Ship logs to Loki | Tail linelog files |
| **Loki** | Log aggregation and querying | Store and index logs |
| **Grafana** | Dashboards and alerting | Visualize NAS activity |

---

## Implementation Details

### 1. FreeRADIUS linelog Module

The `linelog` module writes customizable log lines for specific events.

**New file: `mods-available/linelog`**

```
linelog {
    filename = /var/log/freeradius/linelog/auth.log
    
    Access-Request {
        format = "timestamp=%S nasid=%{NAS-Identifier} nasip=%{NAS-IP-Address} user=%{User-Name} calledstation=%{Called-Station-Id} callingstation=%{Calling-Station-Id} action=auth-request"
    }
    
    Access-Accept {
        format = "timestamp=%S nasid=%{NAS-Identifier} nasip=%{NAS-IP-Address} user=%{User-Name} action=auth-accept"
    }
    
    Access-Reject {
        format = "timestamp=%S nasid=%{NAS-Identifier} nasip=%{NAS-IP-Address} user=%{User-Name} action=auth-reject reason=%{Module-Failure-Message}"
    }
}

linelog linelog_acct {
    filename = /var/log/freeradius/linelog/accounting.log
    
    Accounting-Request {
        format = "timestamp=%S nasid=%{NAS-Identifier} nasip=%{NAS-IP-Address} user=%{User-Name} status=%{Acct-Status-Type} session=%{Acct-Session-Id} bytes_in=%{Acct-Input-Octets} bytes_out=%{Acct-Output-Octets}"
    }
}
```

**Key attributes captured:**

| Attribute | Description | Use Case |
|-----------|-------------|----------|
| `NAS-Identifier` | Hostname/name of access point | Identify which AP sent request |
| `NAS-IP-Address` | IP of access point | Correlate with network infrastructure |
| `Called-Station-Id` | MAC of access point | Hardware identification |
| `Calling-Station-Id` | MAC of client device | Track client devices |
| `User-Name` | Username attempting auth | User activity tracking |
| `Acct-Status-Type` | Start/Stop/Interim-Update | Session lifecycle |
| `Acct-Session-Id` | Unique session identifier | Correlate session events |
| `Acct-Input-Octets` | Bytes received by client | Usage metrics |
| `Acct-Output-Octets` | Bytes sent by client | Usage metrics |

### 2. Remove Debug Mode

**Current entrypoint.sh:**
```bash
exec radiusd -X
```

**Proposed change:**
```bash
exec radiusd -f  # Foreground, no debug
```

The `-f` flag keeps the process in foreground (required for Docker) without debug verbosity.

### 3. Monitor Service Stack

**New directory structure:**
```
monitor/
├── docker-compose.yml
├── .env.example
├── Makefile
├── README.md
└── config/
    ├── grafana/
    │   └── provisioning/
    │       ├── dashboards/
    │       │   └── radius.json
    │       └── datasources/
    │           └── loki.yml
    ├── loki/
    │   └── loki-config.yml
    └── promtail/
        └── promtail-config.yml
```

**docker-compose.yml:**
```yaml
services:
  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./config/loki/loki-config.yml:/etc/loki/local-config.yaml:ro
      - loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - monitor-network
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    volumes:
      - ./config/promtail/promtail-config.yml:/etc/promtail/config.yml:ro
      - radius-logs:/var/log/freeradius:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitor-network
      - radius-network
    depends_on:
      - loki
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  grafana:
    image: grafana/grafana:10.2.0
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      - monitor-network
    depends_on:
      - loki
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  loki-data:
    driver: local
  grafana-data:
    driver: local
  radius-logs:
    external: true
    name: freeradius_radius-data

networks:
  monitor-network:
    driver: bridge
  radius-network:
    external: true
    name: freeradius_radius-network
```

### 4. Promtail Configuration

**promtail-config.yml:**
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: radius-auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: radius
          type: auth
          __path__: /var/log/freeradius/linelog/auth.log

  - job_name: radius-accounting
    static_configs:
      - targets:
          - localhost
        labels:
          job: radius
          type: accounting
          __path__: /var/log/freeradius/linelog/accounting.log

    pipeline_stages:
      - regex:
          expression: 'nasid=(?P<nasid>[^\s]+) nasip=(?P<nasip>[^\s]+) user=(?P<user>[^\s]+)'
      - labels:
          nasid:
          nasip:
          user:
```

### 5. Loki Configuration

**loki-config.yml:**
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2023-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
```

---

## Grafana Dashboard Queries

### Authentication by NAS

```logql
sum by (nasid) (count_over_time({job="radius", type="auth"} |= "action=auth-accept" [5m]))
```

### Failed Authentications

```logql
{job="radius", type="auth"} |= "action=auth-reject"
```

### Top Users by Session Count

```logql
sum by (user) (count_over_time({job="radius", type="accounting"} |= "status=Start" [1h]))
```

### Bandwidth by NAS

```logql
{job="radius", type="accounting"} |= "status=Stop" | regexp `bytes_out=(?P<bytes>\d+)` | unwrap bytes | sum by (nasid)
```

---

## Deployment Order

```
Step 1: Update FreeRADIUS
┌─────────────────────────────────────────┐
│ 1. Add linelog module configuration     │
│ 2. Enable linelog in site config        │
│ 3. Create /var/log/freeradius/linelog/  │
│ 4. Remove -X flag from entrypoint       │
│ 5. Rebuild and redeploy FreeRADIUS      │
└─────────────────────────────────────────┘
                    │
                    ▼
Step 2: Deploy Monitor Stack
┌─────────────────────────────────────────┐
│ 1. Create monitor/ directory            │
│ 2. Configure Loki, Promtail, Grafana    │
│ 3. Deploy with docker compose           │
│ 4. Verify Promtail reading logs         │
└─────────────────────────────────────────┘
                    │
                    ▼
Step 3: Create Dashboards
┌─────────────────────────────────────────┐
│ 1. Import/create Grafana dashboards     │
│ 2. Configure alerts (optional)          │
│ 3. Test with radtest                    │
└─────────────────────────────────────────┘
```

---

## Testing Plan

### Verify linelog Output

```bash
# Generate auth request
make test

# Check linelog output
docker exec freeradius cat /var/log/freeradius/linelog/auth.log
```

Expected output:
```
timestamp=2024-01-15T10:30:00 nasid=test-ap nasip=172.18.0.2 user=test action=auth-accept
```

### Verify Loki Ingestion

```bash
# Query Loki API
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="radius"}' | jq
```

### Verify Grafana

1. Open http://localhost:3000
2. Login with admin credentials
3. Navigate to Explore
4. Select Loki datasource
5. Query `{job="radius"}`

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Log volume grows large | Loki retention policy; log rotation in FreeRADIUS |
| Promtail can't access FreeRADIUS logs | Share volume between containers |
| linelog module not enabled | Add to site-available/default authorize/post-auth sections |
| Missing NAS-Identifier in requests | Some NAS devices don't send it; fall back to NAS-IP-Address |

---

## Open Questions

1. **Retention period**: How long should logs be kept? (Default: no deletion)
2. **Alerting**: What conditions warrant alerts? (Auth failures > threshold?)
3. **Access control**: Who should have Grafana access?
4. **Resource limits**: Memory/CPU constraints for Loki?

---

## Next Steps

1. [ ] Review and approve this design
2. [ ] Implement FreeRADIUS linelog configuration
3. [ ] Create monitor/ service directory
4. [ ] Deploy and test end-to-end
5. [ ] Create Grafana dashboards
