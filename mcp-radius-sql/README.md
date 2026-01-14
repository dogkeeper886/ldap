# MCP RADIUS SQL Server

HTTP-based MCP server for querying RADIUS PostgreSQL data with bearer token authentication.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  MCP Client      │────►│  MCP Server      │────►│  radius-postgres │
│  (HTTP + Token)  │     │  (Express + SDK) │     │  (Docker network)│
└──────────────────┘     └──────────────────┘     └──────────────────┘
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
  -p 3000:3000 \
  -e HTTP_PORT=3000 \
  -e MCP_TOKEN=your-secure-token \
  -e POSTGRES_HOST=postgres \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB=radius \
  -e POSTGRES_USER=radius \
  -e POSTGRES_PASSWORD=radiuspass123 \
  mcp-radius-sql
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HTTP_PORT` | No | 3000 | HTTP server port |
| `MCP_TOKEN` | Yes | - | Bearer token (min 32 chars) |
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
      "url": "http://localhost:3000/mcp",
      "headers": {
        "Authorization": "Bearer your-secure-token"
      }
    }
  }
}
```

## Security

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
