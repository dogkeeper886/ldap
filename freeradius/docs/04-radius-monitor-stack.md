# RADIUS Monitor Stack (Future)

## Overview

This document outlines a future monitoring stack using Grafana and Loki for RADIUS observability. This is **Phase 2** - implement after SQL logging is working.

## Prerequisites

- RADIUS SQL logging operational (see `04-radius-sql-logging.md`)
- PostgreSQL with radacct and radpostauth tables populated

## Architecture

```
┌──────────────┐     ┌──────────────┐
│  PostgreSQL  │────►│   Grafana    │
│              │     │              │
│  radacct     │     │  Dashboards  │
│  radpostauth │     │  Alerts      │
└──────────────┘     └──────────────┘
```

## Option A: Grafana with PostgreSQL Datasource

Since RADIUS data is already in PostgreSQL, Grafana can query it directly.

**Pros:**
- No additional log shipping infrastructure
- SQL queries for dashboards
- Single source of truth

**Cons:**
- Dashboard queries hit production database

## Option B: Add Loki for Log Aggregation

If container logs or additional log sources are needed:

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  FreeRADIUS  │────►│   Promtail   │────►│     Loki     │
│  (stdout)    │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
                                                │
                                                ▼
                                          ┌──────────────┐
                                          │   Grafana    │
                                          └──────────────┘
```

## Implementation Scope

| Component | Purpose | Priority |
|-----------|---------|----------|
| Grafana | Dashboards for SQL data | High |
| PostgreSQL datasource | Query radacct/radpostauth | High |
| Loki | Container log aggregation | Low |
| Promtail | Log shipping | Low |
| Alerting | Failed auth thresholds | Medium |

## Proposed Directory Structure

```
monitor/
├── docker-compose.yml
├── .env.example
├── Makefile
├── README.md
└── config/
    └── grafana/
        └── provisioning/
            ├── dashboards/
            │   └── radius.json
            └── datasources/
                └── postgres.yml
```

## Dashboard Panels (Draft)

1. **Auth Success Rate** - Accept vs Reject over time
2. **Auth by NAS** - Which access points are active
3. **Active Sessions** - Current connected users
4. **Bandwidth by User** - Top consumers
5. **Failed Auth Attempts** - Security monitoring

## Open Questions

1. Deploy Grafana in monitor/ or add to freeradius/?
2. Alerting destinations (email, Slack, webhook)?
3. Retention policy for dashboard data?

## Next Steps

1. Complete SQL logging implementation
2. Verify data in PostgreSQL tables
3. Deploy Grafana with PostgreSQL datasource
4. Create initial dashboards
5. (Optional) Add Loki if log aggregation needed
