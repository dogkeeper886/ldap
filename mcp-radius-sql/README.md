# MCP RADIUS SQL Server

HTTPS-based MCP server for querying RADIUS PostgreSQL data with bearer token authentication.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  MCP Client      │────►│  MCP Server      │────►│  radius-postgres │
│  (HTTPS + Token) │     │  (Express + TLS) │     │  (Docker network)│
└──────────────────┘     └──────────────────┘     └──────────────────┘
        │                       │                       │
   Authorization:          POST /mcp              postgres:5432
   Bearer <token>          GET /mcp (SSE)         (internal DNS)
                           GET /health
                           Port 3443 (HTTPS)
```

## Prerequisites

- Node.js >= 18
- FreeRADIUS with PostgreSQL running (see `freeradius/` project)
- Docker (for containerized deployment)

## Setup

### 1. Configure Environment

```bash
cp .env.example .env
# Edit .env with your settings
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Build

```bash
npm run build
```

### 4. Run

```bash
npm start
```

## Docker Deployment

### Build Image

```bash
docker build -t mcp-radius-sql .
```

### Run Container

```bash
docker run -d \
  --name mcp-radius-sql \
  --network freeradius_default \
  -p 3443:3000 \
  -e HTTP_PORT=3000 \
  -e MCP_TOKEN=your-secure-token \
  -e HTTPS_ENABLED=true \
  -e TLS_CERT_FILE=/app/certs/fullchain.pem \
  -e TLS_KEY_FILE=/app/certs/privkey.pem \
  -e POSTGRES_HOST=postgres \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB=radius \
  -e POSTGRES_USER=radius \
  -e POSTGRES_PASSWORD=radiuspass123 \
  mcp-radius-sql
```

## HTTPS Setup

### Using Let's Encrypt Certificates

1. Copy certificates from certbot container:

```bash
cd mcp-radius-sql
./scripts/copy-certs-for-build.sh
```

2. Build and deploy with docker-compose:

```bash
make deploy
# Or from freeradius directory:
cd ../freeradius && make mcp-deploy
```

3. Verify HTTPS is working:

```bash
curl -k https://localhost:3443/health
```

### Certificate Configuration

The server expects certificates at:
- `/app/certs/fullchain.pem` - Certificate chain
- `/app/certs/privkey.pem` - Private key

Override paths via `TLS_CERT_FILE` and `TLS_KEY_FILE` environment variables.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HTTP_PORT` | No | 3000 | Server port |
| `MCP_TOKEN` | Yes | - | Bearer token (min 32 chars) |
| `HTTPS_ENABLED` | No | false | Enable HTTPS |
| `TLS_CERT_FILE` | No | /app/certs/fullchain.pem | TLS certificate |
| `TLS_KEY_FILE` | No | /app/certs/privkey.pem | TLS private key |
| `POSTGRES_HOST` | Yes | - | PostgreSQL host |
| `POSTGRES_PORT` | No | 5432 | PostgreSQL port |
| `POSTGRES_DB` | Yes | - | Database name |
| `POSTGRES_USER` | Yes | - | Database user |
| `POSTGRES_PASSWORD` | Yes | - | Database password |
| `LOG_LEVEL` | No | info | Log level (debug/info/warn/error) |

## API Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/health` | GET | No | Health check |
| `/mcp` | POST | Yes | MCP requests |
| `/mcp` | GET | Yes | SSE notifications |
| `/mcp/sessions/:id` | DELETE | Yes | Close session |

## MCP Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `radius_auth_recent` | Recent auth attempts | `limit` (default: 20) |
| `radius_failed_auth` | Failed auth attempts | `hours`, `limit` |
| `radius_by_mac` | Search by MAC address | `mac` |
| `radius_by_user` | Search by username | `username` |
| `radius_acct_recent` | Recent accounting | `limit` |
| `radius_active_sessions` | Active sessions | none |
| `radius_by_nas` | Search by NAS | `nas_identifier` |
| `radius_bandwidth_top` | Top bandwidth users | `hours`, `limit` |
| `radius_health` | Database health | none |

## Claude Code Configuration

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "radius-sql": {
      "url": "https://localhost:3443/mcp",
      "headers": {
        "Authorization": "Bearer your-secure-token"
      }
    }
  }
}
```

## Security

- HTTPS with TLS 1.2+ for encrypted transport
- Bearer token authentication required for MCP endpoints
- Timing-safe token comparison to prevent enumeration
- Read-only PostgreSQL queries (no writes)
- Parameterized queries to prevent SQL injection
- Credentials never logged

## Development

```bash
# Run in development mode
npm run dev

# Run tests
npm test

# Watch tests
npm run test:watch
```
