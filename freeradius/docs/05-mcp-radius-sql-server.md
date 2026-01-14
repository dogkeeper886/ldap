# MCP RADIUS SQL Server

## Problem Statement

| Issue | Current State | Impact |
|-------|---------------|--------|
| Manual SQL queries | Must run `make sql-*` commands or `docker exec` | Slow debugging workflow |
| No programmatic access | Cannot integrate with AI assistants or automation | Limited observability |
| Context switching | Jump between terminal and tools | Productivity loss |

## Solution

Create an MCP (Model Context Protocol) server that provides:
1. Direct PostgreSQL queries for RADIUS data
2. Pre-built query tools matching Makefile commands
3. Real-time access to authentication and accounting data

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Claude Code     │────►│  MCP Server      │────►│  PostgreSQL      │
│  (or other MCP   │     │  (radius-sql)    │     │  (radius-postgres)│
│   client)        │◄────│                  │◄────│                  │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

## Prerequisites

1. RADIUS SQL logging operational (see `04-radius-sql-logging.md`)
2. PostgreSQL container running with radacct/radpostauth tables
3. Node.js >= 18 installed on host
4. PostgreSQL port exposed for host access:
   ```yaml
   # docker-compose.yml
   postgres:
     ports:
       - "127.0.0.1:5432:5432"  # Local only
   ```

## Technology Stack

| Component | Library | Version | Purpose |
|-----------|---------|---------|---------|
| Runtime | Node.js | >= 18 | ES modules, native fetch |
| Language | TypeScript | ^5.0 | Type safety |
| MCP SDK | @modelcontextprotocol/sdk | ^1.0.0 | MCP protocol implementation |
| Database | pg | ^8.11.3 | PostgreSQL client |
| Validation | zod | ^3.22.0 | Runtime schema validation |
| Logging | pino | ^8.16.0 | Structured JSON logging |
| Config | dotenv | ^16.3.0 | Environment variable loading |
| Testing | vitest | ^1.0.0 | Unit and integration tests |

## Architecture

### Project Structure

```
mcp-radius-sql/
├── package.json
├── tsconfig.json
├── .env.example
├── src/
│   ├── index.ts          # MCP server entry point
│   ├── config.ts         # Configuration with validation
│   ├── logger.ts         # Pino logger setup
│   ├── db/
│   │   ├── pool.ts       # PostgreSQL connection pool
│   │   └── health.ts     # Database health check
│   ├── tools/
│   │   ├── index.ts      # Tool registry
│   │   ├── schemas.ts    # Zod schemas for tool inputs
│   │   ├── auth.ts       # Authentication query tools
│   │   ├── acct.ts       # Accounting query tools
│   │   └── stats.ts      # Statistics tools
│   └── errors.ts         # Custom error types
├── tests/
│   ├── tools.test.ts
│   └── queries.test.ts
└── README.md
```

### Connection Strategy

**Option A: Direct PostgreSQL Connection** (Recommended)
- MCP server connects directly to PostgreSQL via exposed port
- Best for: Local development, same-host deployment

**Option B: Docker Exec Wrapper**
- MCP server executes `docker exec radius-postgres psql ...`
- Best for: Remote access, firewall constraints

## MCP Tools

### 1. Query Tools (Pre-built)

| Tool Name | Description | Parameters |
|-----------|-------------|------------|
| `radius_auth_recent` | Recent authentication attempts | `limit` (default: 20) |
| `radius_acct_recent` | Recent accounting sessions | `limit` (default: 20) |
| `radius_by_mac` | Auth/accounting by MAC address | `mac` (required) |
| `radius_by_user` | Auth/accounting by username | `username` (required) |
| `radius_by_nas` | Auth/accounting by NAS identifier | `nas_identifier` (required) |
| `radius_active_sessions` | Currently active sessions | none |
| `radius_failed_auth` | Recent failed authentications | `limit`, `hours` (default: 24) |
| `radius_bandwidth_top` | Top bandwidth consumers | `limit`, `hours` |

### 2. Health Tool

| Tool Name | Description | Parameters |
|-----------|-------------|------------|
| `radius_health` | Check database connectivity | none |

### 3. Statistics Tools

| Tool Name | Description | Parameters |
|-----------|-------------|------------|
| `radius_auth_stats` | Auth success/fail rates | `hours` (default: 24) |
| `radius_nas_stats` | Per-NAS statistics | `hours` (default: 24) |

## Implementation

### Configuration with Validation

```typescript
// src/config.ts
import { z } from 'zod';
import 'dotenv/config';

const configSchema = z.object({
  postgres: z.object({
    host: z.string().min(1),
    port: z.coerce.number().int().positive(),
    database: z.string().min(1),
    user: z.string().min(1),
    password: z.string().min(1),
  }),
  log: z.object({
    level: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  }),
});

function loadConfig() {
  const result = configSchema.safeParse({
    postgres: {
      host: process.env.POSTGRES_HOST,
      port: process.env.POSTGRES_PORT || 5432,
      database: process.env.POSTGRES_DB,
      user: process.env.POSTGRES_USER,
      password: process.env.POSTGRES_PASSWORD,
    },
    log: {
      level: process.env.LOG_LEVEL,
    },
  });

  if (!result.success) {
    console.error('Configuration error:', result.error.format());
    process.exit(1);
  }

  return result.data;
}

export const config = loadConfig();
```

### Structured Logging

```typescript
// src/logger.ts
import pino from 'pino';
import { config } from './config.js';

export const logger = pino({
  level: config.log.level,
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
```

### Database Pool with Health Check

```typescript
// src/db/pool.ts
import pg from 'pg';
import { config } from '../config.js';
import { logger } from '../logger.js';

export const pool = new pg.Pool({
  host: config.postgres.host,
  port: config.postgres.port,
  database: config.postgres.database,
  user: config.postgres.user,
  password: config.postgres.password,
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  logger.error({ err }, 'Unexpected database pool error');
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, closing pool');
  await pool.end();
  process.exit(0);
});
```

```typescript
// src/db/health.ts
import { pool } from './pool.js';

export async function checkHealth(): Promise<{ ok: boolean; latencyMs: number }> {
  const start = Date.now();
  try {
    await pool.query('SELECT 1');
    return { ok: true, latencyMs: Date.now() - start };
  } catch {
    return { ok: false, latencyMs: Date.now() - start };
  }
}
```

### Tool Input Schemas

```typescript
// src/tools/schemas.ts
import { z } from 'zod';

export const limitSchema = z.object({
  limit: z.number().int().min(1).max(100).default(20),
});

export const macSchema = z.object({
  mac: z.string().regex(/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/, 
    'Invalid MAC address format'),
});

export const usernameSchema = z.object({
  username: z.string().min(1).max(64),
});

export const timeRangeSchema = z.object({
  hours: z.number().int().min(1).max(720).default(24),
  limit: z.number().int().min(1).max(100).default(20),
});
```

### Tool Implementation with Error Handling

```typescript
// src/tools/auth.ts
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { logger } from '../logger.js';
import { limitSchema, macSchema, timeRangeSchema } from './schemas.js';

export const authTools = {
  radius_auth_recent: {
    description: 'Get recent RADIUS authentication attempts',
    inputSchema: limitSchema,
    handler: async (input: unknown) => {
      const { limit } = limitSchema.parse(input);
      logger.info({ tool: 'radius_auth_recent', limit }, 'Executing query');
      
      const result = await pool.query(`
        SELECT authdate, username, reply, nasidentifier, 
               nasipaddress, calledstationid, callingstationid
        FROM radpostauth 
        ORDER BY authdate DESC 
        LIMIT $1
      `, [limit]);
      
      return { content: [{ type: 'text', text: JSON.stringify(result.rows, null, 2) }] };
    },
  },

  radius_failed_auth: {
    description: 'Get recent failed authentication attempts',
    inputSchema: timeRangeSchema,
    handler: async (input: unknown) => {
      const { hours, limit } = timeRangeSchema.parse(input);
      logger.info({ tool: 'radius_failed_auth', hours, limit }, 'Executing query');
      
      const result = await pool.query(`
        SELECT authdate, username, nasidentifier, callingstationid
        FROM radpostauth 
        WHERE reply != 'Access-Accept'
          AND authdate > NOW() - INTERVAL '1 hour' * $1
        ORDER BY authdate DESC 
        LIMIT $2
      `, [hours, limit]);
      
      return { content: [{ type: 'text', text: JSON.stringify(result.rows, null, 2) }] };
    },
  },

  radius_by_mac: {
    description: 'Get authentication and accounting records by MAC address',
    inputSchema: macSchema,
    handler: async (input: unknown) => {
      const { mac } = macSchema.parse(input);
      // Normalize MAC format for ILIKE query
      const macPattern = `%${mac.replace(/[:-]/g, '')}%`;
      logger.info({ tool: 'radius_by_mac', mac }, 'Executing query');
      
      const [auth, acct] = await Promise.all([
        pool.query(`
          SELECT authdate, username, reply, nasidentifier
          FROM radpostauth 
          WHERE REPLACE(REPLACE(callingstationid, '-', ''), ':', '') ILIKE $1
          ORDER BY authdate DESC LIMIT 10
        `, [macPattern]),
        pool.query(`
          SELECT acctstarttime, username, nasidentifier, acctstoptime, acctterminatecause
          FROM radacct 
          WHERE REPLACE(REPLACE(callingstationid, '-', ''), ':', '') ILIKE $1
          ORDER BY acctstarttime DESC LIMIT 10
        `, [macPattern]),
      ]);
      
      return { 
        content: [{ 
          type: 'text', 
          text: JSON.stringify({ auth: auth.rows, acct: acct.rows }, null, 2) 
        }] 
      };
    },
  },
};
```

### MCP Server Entry Point

```typescript
// src/index.ts
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { logger } from './logger.js';
import { checkHealth } from './db/health.js';
import { authTools } from './tools/auth.js';
import { acctTools } from './tools/acct.js';
import { ZodError } from 'zod';

const allTools = { ...authTools, ...acctTools };

const server = new Server(
  { name: 'radius-sql', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: Object.entries(allTools).map(([name, tool]) => ({
    name,
    description: tool.description,
    inputSchema: {
      type: 'object',
      properties: tool.inputSchema.shape,
    },
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const tool = allTools[name as keyof typeof allTools];
  
  if (!tool) {
    return { content: [{ type: 'text', text: `Unknown tool: ${name}` }], isError: true };
  }

  try {
    return await tool.handler(args);
  } catch (error) {
    if (error instanceof ZodError) {
      logger.warn({ tool: name, error: error.errors }, 'Validation error');
      return { 
        content: [{ type: 'text', text: `Validation error: ${error.errors.map(e => e.message).join(', ')}` }],
        isError: true,
      };
    }
    logger.error({ tool: name, error }, 'Tool execution failed');
    return { 
      content: [{ type: 'text', text: `Error: ${error instanceof Error ? error.message : 'Unknown error'}` }],
      isError: true,
    };
  }
});

async function main() {
  // Health check on startup
  const health = await checkHealth();
  if (!health.ok) {
    logger.error('Database health check failed on startup');
    process.exit(1);
  }
  logger.info({ latencyMs: health.latencyMs }, 'Database connected');

  const transport = new StdioServerTransport();
  await server.connect(transport);
  logger.info('MCP server started');
}

main().catch((error) => {
  logger.error({ error }, 'Fatal error');
  process.exit(1);
});
```

### Package Configuration

```json
{
  "name": "mcp-radius-sql",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "tsx src/index.ts",
    "test": "vitest",
    "lint": "eslint src/"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "dotenv": "^16.3.0",
    "pg": "^8.11.3",
    "pino": "^8.16.0",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/pg": "^8.10.0",
    "tsx": "^4.0.0",
    "typescript": "^5.3.0",
    "vitest": "^1.0.0"
  }
}
```

## Deployment

### Option 1: Local Development (Recommended)

1. Expose PostgreSQL port in docker-compose.yml:
   ```yaml
   postgres:
     ports:
       - "127.0.0.1:5432:5432"
   ```

2. Create `.env` file:
   ```bash
   POSTGRES_HOST=localhost
   POSTGRES_PORT=5432
   POSTGRES_DB=radius
   POSTGRES_USER=radius
   POSTGRES_PASSWORD=radiuspass123
   LOG_LEVEL=info
   ```

3. Build and run:
   ```bash
   cd mcp-radius-sql
   npm install
   npm run build
   npm start
   ```

4. Configure Claude Code (`~/.claude.json`):
   ```json
   {
     "mcpServers": {
       "radius-sql": {
         "command": "node",
         "args": ["/home/jack_tseng/ldap/mcp-radius-sql/dist/index.js"],
         "env": {
           "POSTGRES_HOST": "localhost",
           "POSTGRES_PORT": "5432",
           "POSTGRES_DB": "radius",
           "POSTGRES_USER": "radius",
           "POSTGRES_PASSWORD": "radiuspass123"
         }
       }
     }
   }
   ```

## Security

| Concern | Mitigation |
|---------|------------|
| SQL Injection | Parameterized queries only |
| Input Validation | Zod schemas validate all inputs |
| Data exposure | Read-only SELECT queries |
| Network access | PostgreSQL bound to localhost only |
| Credentials | Environment variables, never logged |
| Error exposure | Structured errors, no stack traces to client |

## Error Handling Strategy

| Error Type | Handling | User Message |
|------------|----------|--------------|
| Validation (Zod) | Return validation errors | "Validation error: {details}" |
| Database connection | Log + fail fast | "Database connection failed" |
| Query error | Log + return error | "Query failed: {message}" |
| Unknown tool | Return error | "Unknown tool: {name}" |

## Logging Guidelines

- **Info**: Tool execution start, database connected
- **Warn**: Validation errors, recoverable issues  
- **Error**: Database errors, unexpected failures
- **Never log**: Passwords, full query results, sensitive user data

## Testing Strategy

```typescript
// tests/tools.test.ts
import { describe, it, expect, vi } from 'vitest';
import { authTools } from '../src/tools/auth.js';

describe('radius_auth_recent', () => {
  it('validates limit parameter', async () => {
    const result = await authTools.radius_auth_recent.handler({ limit: -1 });
    expect(result.isError).toBe(true);
  });

  it('uses default limit when not provided', async () => {
    // Mock pool.query and verify limit = 20
  });
});
```

## Files to Create

| File | Purpose |
|------|---------|
| `package.json` | Dependencies and scripts |
| `tsconfig.json` | TypeScript configuration |
| `.env.example` | Environment variable template |
| `src/index.ts` | MCP server entry point |
| `src/config.ts` | Configuration with Zod validation |
| `src/logger.ts` | Pino logger setup |
| `src/db/pool.ts` | PostgreSQL connection pool |
| `src/db/health.ts` | Health check function |
| `src/tools/schemas.ts` | Zod input schemas |
| `src/tools/auth.ts` | Authentication query tools |
| `src/tools/acct.ts` | Accounting query tools |
| `src/errors.ts` | Custom error types |
| `tests/*.test.ts` | Unit tests |
| `README.md` | Usage documentation |

## Implementation Steps

1. Create project directory and initialize npm
2. Configure TypeScript
3. Implement configuration module with validation
4. Set up Pino logger
5. Create database pool with health check
6. Define Zod schemas for tool inputs
7. Implement tool handlers
8. Create MCP server entry point
9. Add unit tests
10. Configure Claude Code MCP settings
11. Test end-to-end

## Related Documents

- `04-radius-sql-logging.md` - SQL schema and logging setup
- `06-radius-monitor-stack.md` - Grafana monitoring (future)
