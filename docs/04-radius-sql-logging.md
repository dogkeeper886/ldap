# RADIUS SQL Logging

## Problem Statement

| Issue | Current State | Impact |
|-------|---------------|--------|
| No NAS-Identifier visibility | Auth/accounting not logged to queryable storage | Cannot identify which access points send requests |
| Console debug logging | Running with `-X` flag | Not suitable for production |

## Solution

Use FreeRADIUS SQL module (`rlm_sql`) to log authentication and accounting to PostgreSQL.

```
┌──────────────┐     ┌──────────────┐
│  FreeRADIUS  │────►│  PostgreSQL  │
│              │     │              │
│  rlm_sql     │     │  radacct     │
│  module      │     │  radpostauth │
└──────────────┘     └──────────────┘
```

## Tables

### radacct (Accounting)

| Column | Type | Description |
|--------|------|-------------|
| `radacctid` | bigint | Primary key |
| `acctsessionid` | varchar(64) | Session identifier |
| `username` | varchar(64) | User-Name |
| `nasipaddress` | varchar(15) | NAS-IP-Address |
| `nasidentifier` | varchar(64) | NAS-Identifier (custom) |
| `calledstationid` | varchar(50) | AP MAC address |
| `callingstationid` | varchar(50) | Client MAC address |
| `acctstarttime` | datetime | Session start |
| `acctstoptime` | datetime | Session end |
| `acctsessiontime` | int | Duration (seconds) |
| `acctinputoctets` | bigint | Bytes received |
| `acctoutputoctets` | bigint | Bytes sent |

### radpostauth (Authentication)

| Column | Type | Description |
|--------|------|-------------|
| `id` | int | Primary key |
| `username` | varchar(64) | User-Name |
| `pass` | varchar(64) | Password (masked) |
| `reply` | varchar(32) | Access-Accept/Reject |
| `nasidentifier` | varchar(64) | NAS-Identifier (custom) |
| `nasipaddress` | varchar(15) | NAS-IP-Address (custom) |
| `calledstationid` | varchar(50) | AP MAC (custom) |
| `callingstationid` | varchar(50) | Client MAC (custom) |
| `authdate` | timestamp | When auth occurred |

## Implementation

### 1. Add PostgreSQL to FreeRADIUS docker-compose

```yaml
services:
  postgres:
    image: postgres:15-alpine
    container_name: radius-postgres
    environment:
      POSTGRES_DB: radius
      POSTGRES_USER: radius
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./sql/schema.sql:/docker-entrypoint-initdb.d/schema.sql:ro
    networks:
      - radius-network

volumes:
  postgres-data:
    driver: local
```

### 2. Create schema with NAS-Identifier

**freeradius/sql/schema.sql:**

```sql
-- Accounting table (extended with nasidentifier)
CREATE TABLE radacct (
    radacctid BIGSERIAL PRIMARY KEY,
    acctsessionid VARCHAR(64) NOT NULL,
    acctuniqueid VARCHAR(32) NOT NULL UNIQUE,
    username VARCHAR(64) NOT NULL,
    nasipaddress VARCHAR(15) NOT NULL,
    nasidentifier VARCHAR(64) DEFAULT '',
    nasportid VARCHAR(32),
    nasporttype VARCHAR(32),
    acctstarttime TIMESTAMP WITH TIME ZONE,
    acctupdatetime TIMESTAMP WITH TIME ZONE,
    acctstoptime TIMESTAMP WITH TIME ZONE,
    acctsessiontime INTEGER,
    acctinputoctets BIGINT,
    acctoutputoctets BIGINT,
    calledstationid VARCHAR(50) NOT NULL DEFAULT '',
    callingstationid VARCHAR(50) NOT NULL DEFAULT '',
    acctterminatecause VARCHAR(32) NOT NULL DEFAULT '',
    servicetype VARCHAR(32),
    framedprotocol VARCHAR(32),
    framedipaddress VARCHAR(15) NOT NULL DEFAULT '',
    class VARCHAR(64)
);

CREATE INDEX idx_radacct_username ON radacct(username);
CREATE INDEX idx_radacct_nasipaddress ON radacct(nasipaddress);
CREATE INDEX idx_radacct_nasidentifier ON radacct(nasidentifier);
CREATE INDEX idx_radacct_acctstarttime ON radacct(acctstarttime);
CREATE INDEX idx_radacct_acctstoptime ON radacct(acctstoptime);

-- Post-auth table (extended with NAS info)
CREATE TABLE radpostauth (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(64) NOT NULL,
    pass VARCHAR(64),
    reply VARCHAR(32),
    nasidentifier VARCHAR(64) DEFAULT '',
    nasipaddress VARCHAR(15) DEFAULT '',
    calledstationid VARCHAR(50) DEFAULT '',
    callingstationid VARCHAR(50) DEFAULT '',
    authdate TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_radpostauth_username ON radpostauth(username);
CREATE INDEX idx_radpostauth_nasidentifier ON radpostauth(nasidentifier);
CREATE INDEX idx_radpostauth_authdate ON radpostauth(authdate);
```

### 3. Configure FreeRADIUS SQL module

**freeradius/config/mods-available/sql:**

```
sql {
    driver = "rlm_sql_postgresql"
    dialect = "postgresql"
    
    server = "radius-postgres"
    port = 5432
    login = "radius"
    password = "${POSTGRES_PASSWORD}"
    radius_db = "radius"
    
    read_clients = no
    
    accounting {
        reference = "%{tolower:type.%{Acct-Status-Type}.query}"
        type {
            start {
                query = "INSERT INTO radacct \
                    (acctsessionid, acctuniqueid, username, nasipaddress, nasidentifier, \
                     nasportid, nasporttype, acctstarttime, calledstationid, callingstationid, \
                     servicetype, framedprotocol, framedipaddress) \
                    VALUES ('%{Acct-Session-Id}', '%{Acct-Unique-Session-Id}', '%{User-Name}', \
                            '%{NAS-IP-Address}', '%{NAS-Identifier}', '%{NAS-Port-Id}', \
                            '%{NAS-Port-Type}', NOW(), '%{Called-Station-Id}', \
                            '%{Calling-Station-Id}', '%{Service-Type}', '%{Framed-Protocol}', \
                            '%{Framed-IP-Address}')"
            }
            stop {
                query = "UPDATE radacct SET \
                    acctstoptime = NOW(), \
                    acctsessiontime = '%{Acct-Session-Time}', \
                    acctinputoctets = '%{Acct-Input-Octets}', \
                    acctoutputoctets = '%{Acct-Output-Octets}', \
                    acctterminatecause = '%{Acct-Terminate-Cause}' \
                    WHERE acctuniqueid = '%{Acct-Unique-Session-Id}'"
            }
            interim-update {
                query = "UPDATE radacct SET \
                    acctupdatetime = NOW(), \
                    acctsessiontime = '%{Acct-Session-Time}', \
                    acctinputoctets = '%{Acct-Input-Octets}', \
                    acctoutputoctets = '%{Acct-Output-Octets}' \
                    WHERE acctuniqueid = '%{Acct-Unique-Session-Id}'"
            }
        }
    }
    
    post-auth {
        query = "INSERT INTO radpostauth \
            (username, pass, reply, nasidentifier, nasipaddress, calledstationid, callingstationid, authdate) \
            VALUES ('%{User-Name}', '%{User-Password}', '%{reply:Packet-Type}', \
                    '%{NAS-Identifier}', '%{NAS-IP-Address}', '%{Called-Station-Id}', \
                    '%{Calling-Station-Id}', NOW())"
    }
}
```

### 4. Enable SQL in site config

**freeradius/config/sites-available/default:**

```
authorize {
    preprocess
    eap {
        ok = return
    }
    files
    -ldap
}

accounting {
    sql
}

post-auth {
    sql
    
    Post-Auth-Type REJECT {
        sql
    }
}
```

### 5. Enable SQL module

```bash
cd /etc/raddb/mods-enabled
ln -s ../mods-available/sql sql
```

### 6. Remove debug mode

**freeradius/entrypoint.sh:**

Change:
```bash
exec radiusd -X
```

To:
```bash
exec radiusd -f
```

## Deployment Steps

1. Add PostgreSQL service to docker-compose.yml
2. Create sql/schema.sql with extended schema
3. Add SQL module config to mods-available/sql
4. Enable SQL in sites-available/default
5. Create symlink in mods-enabled
6. Update entrypoint.sh to remove -X flag
7. Add POSTGRES_PASSWORD to .env
8. Rebuild and deploy

## Verification

```bash
# Test authentication
make test

# Check radpostauth table
docker exec radius-postgres psql -U radius -d radius -c \
  "SELECT username, reply, nasidentifier, nasipaddress, authdate FROM radpostauth ORDER BY authdate DESC LIMIT 5;"

# Check radacct table
docker exec radius-postgres psql -U radius -d radius -c \
  "SELECT username, nasidentifier, nasipaddress, acctstarttime, acctstoptime FROM radacct ORDER BY acctstarttime DESC LIMIT 5;"
```

## Example Queries

```sql
-- Auth attempts by NAS
SELECT nasidentifier, COUNT(*) as attempts, 
       SUM(CASE WHEN reply = 'Access-Accept' THEN 1 ELSE 0 END) as accepts,
       SUM(CASE WHEN reply = 'Access-Reject' THEN 1 ELSE 0 END) as rejects
FROM radpostauth
WHERE authdate > NOW() - INTERVAL '1 hour'
GROUP BY nasidentifier;

-- Active sessions by NAS
SELECT nasidentifier, COUNT(*) as sessions
FROM radacct
WHERE acctstoptime IS NULL
GROUP BY nasidentifier;

-- Bandwidth by user (last 24h)
SELECT username, 
       SUM(acctinputoctets)/1024/1024 as mb_in,
       SUM(acctoutputoctets)/1024/1024 as mb_out
FROM radacct
WHERE acctstarttime > NOW() - INTERVAL '24 hours'
GROUP BY username
ORDER BY mb_out DESC;
```

## Files Changed

| File | Change |
|------|--------|
| `freeradius/docker-compose.yml` | Add PostgreSQL service |
| `freeradius/sql/schema.sql` | New - database schema |
| `freeradius/config/mods-available/sql` | New - SQL module config |
| `freeradius/config/sites-available/default` | Enable sql in accounting/post-auth |
| `freeradius/config/mods-enabled/sql` | Symlink to enable module |
| `freeradius/entrypoint.sh` | Remove -X flag |
| `freeradius/.env.example` | Add POSTGRES_PASSWORD |
