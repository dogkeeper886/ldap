import express from 'express';
import https from 'node:https';
import fs from 'node:fs';
import { randomUUID } from 'node:crypto';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { config } from './config.js';
import { logger } from './logger.js';
import { checkHealth } from './db/health.js';
import { closePool } from './db/pool.js';
import { authMiddleware } from './auth/middleware.js';
import {
  radiusAuthRecent,
  radiusFailedAuth,
  radiusByMac,
  radiusByUser,
} from './tools/auth.js';
import {
  radiusAcctRecent,
  radiusActiveSessions,
  radiusByNas,
  radiusBandwidthTop,
} from './tools/acct.js';
import {
  limitSchema,
  macSchema,
  usernameSchema,
  nasSchema,
  timeRangeSchema,
} from './tools/schemas.js';
import {
  createUser,
  getUser,
  updateUser,
  deleteUser,
  listUsers,
} from './tools/users.js';
import {
  createUserSchema,
  updateUserSchema,
  listUsersSchema,
  userIdentifierSchema,
} from './tools/user-schemas.js';

const app = express();
app.use(express.json());

// Create MCP server
const mcp = new McpServer({
  name: 'radius-sql',
  version: '1.0.0',
});

// Register tools
mcp.tool(
  'radius_auth_recent',
  'Get recent RADIUS authentication attempts',
  { limit: z.coerce.number().int().min(1).max(100).default(20).describe('Number of records to return') },
  async (args) => {
    const result = await radiusAuthRecent(args);
    return { content: [{ type: 'text', text: result }] };
  }
);

mcp.tool(
  'radius_failed_auth',
  'Get recent failed authentication attempts',
  {
    hours: z.coerce.number().int().min(1).max(720).default(24).describe('Hours to look back'),
    limit: z.coerce.number().int().min(1).max(100).default(20).describe('Number of records to return'),
  },
  async (args) => {
    const result = await radiusFailedAuth(args);
    return { content: [{ type: 'text', text: result }] };
  }
);

mcp.tool(
  'radius_by_mac',
  'Get authentication and accounting records by MAC address',
  { mac: z.string().describe('MAC address (format: XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX)') },
  async (args) => {
    const result = await radiusByMac(args);
    return { content: [{ type: 'text', text: result }] };
  }
);

mcp.tool(
  'radius_by_user',
  'Get authentication and accounting records by username',
  { username: z.string().min(1).max(64).describe('Username to search for') },
  async (args) => {
    const result = await radiusByUser(args);
    return { content: [{ type: 'text', text: result }] };
  }
);

mcp.tool(
  'radius_acct_recent',
  'Get recent RADIUS accounting sessions',
  { limit: z.coerce.number().int().min(1).max(100).default(20).describe('Number of records to return') },
  async (args) => {
    const result = await radiusAcctRecent(args);
    return { content: [{ type: 'text', text: result }] };
  }
);

mcp.tool(
  'radius_active_sessions',
  'Get currently active RADIUS sessions',
  {},
  async () => {
    const result = await radiusActiveSessions({});
    return { content: [{ type: 'text', text: result }] };
  }
);

mcp.tool(
  'radius_by_nas',
  'Get authentication and accounting records by NAS identifier',
  { nas_identifier: z.string().min(1).max(128).describe('NAS identifier to search for') },
  async (args) => {
    const result = await radiusByNas(args);
    return { content: [{ type: 'text', text: result }] };
  }
);

mcp.tool(
  'radius_bandwidth_top',
  'Get top bandwidth consumers',
  {
    hours: z.coerce.number().int().min(1).max(720).default(24).describe('Hours to look back'),
    limit: z.coerce.number().int().min(1).max(100).default(20).describe('Number of records to return'),
  },
  async (args) => {
    const result = await radiusBandwidthTop(args);
    return { content: [{ type: 'text', text: result }] };
  }
);

mcp.tool(
  'radius_health',
  'Check database connectivity',
  {},
  async () => {
    const health = await checkHealth();
    return { content: [{ type: 'text', text: JSON.stringify(health, null, 2) }] };
  }
);

mcp.tool(
  'radius_user_create',
  'Create a new RADIUS user with password and optional groups',
  {
    username: createUserSchema.shape.username.describe('Username (alphanumeric, dots, underscores, hyphens)'),
    password: createUserSchema.shape.password.describe('User password (min 4 chars)'),
    groups: createUserSchema.shape.groups.describe('Optional list of groups to assign'),
    session_timeout: createUserSchema.shape.session_timeout.describe('Optional session timeout in seconds'),
    reply_attributes: createUserSchema.shape.reply_attributes.describe(
      'Optional array of reply attributes [{attribute, op, value}]. Use for Tunnel-Password, Reply-Message, etc.'
    ),
  },
  async (args) => {
    try {
      const result = await createUser(args);
      return { content: [{ type: 'text', text: result }] };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      return { content: [{ type: 'text', text: JSON.stringify({ error: message }) }], isError: true };
    }
  }
);

mcp.tool(
  'radius_user_get',
  'Get details of a RADIUS user (excludes password)',
  {
    username: userIdentifierSchema.shape.username.describe('Username to look up'),
  },
  async (args) => {
    try {
      const result = await getUser(args);
      return { content: [{ type: 'text', text: result }] };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      return { content: [{ type: 'text', text: JSON.stringify({ error: message }) }], isError: true };
    }
  }
);

mcp.tool(
  'radius_user_update',
  'Update an existing RADIUS user (password, groups, enabled state)',
  {
    username: updateUserSchema.shape.username.describe('Username to update'),
    password: updateUserSchema.shape.password.describe('New password (optional)'),
    groups: updateUserSchema.shape.groups.describe('New group list (optional, replaces existing)'),
    session_timeout: updateUserSchema.shape.session_timeout.describe('New session timeout in seconds (optional)'),
    enabled: updateUserSchema.shape.enabled.describe('Enable or disable user (optional)'),
    reply_attributes: updateUserSchema.shape.reply_attributes.describe(
      'Optional array of reply attributes [{attribute, op, value}]. Use for Tunnel-Password, Reply-Message, etc.'
    ),
  },
  async (args) => {
    try {
      const result = await updateUser(args);
      return { content: [{ type: 'text', text: result }] };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      return { content: [{ type: 'text', text: JSON.stringify({ error: message }) }], isError: true };
    }
  }
);

mcp.tool(
  'radius_user_delete',
  'Delete a RADIUS user',
  {
    username: userIdentifierSchema.shape.username.describe('Username to delete'),
  },
  async (args) => {
    try {
      const result = await deleteUser(args);
      return { content: [{ type: 'text', text: result }] };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      return { content: [{ type: 'text', text: JSON.stringify({ error: message }) }], isError: true };
    }
  }
);

mcp.tool(
  'radius_user_list',
  'List RADIUS users with pagination and optional search',
  {
    limit: listUsersSchema.shape.limit.describe('Maximum number of users to return (default 50)'),
    offset: listUsersSchema.shape.offset.describe('Number of users to skip (default 0)'),
    search: listUsersSchema.shape.search.describe('Optional username search pattern'),
  },
  async (args) => {
    try {
      const result = await listUsers(args);
      return { content: [{ type: 'text', text: result }] };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      return { content: [{ type: 'text', text: JSON.stringify({ error: message }) }], isError: true };
    }
  }
);

// Session management for stateful connections
const transports = new Map<string, StreamableHTTPServerTransport>();

// Health endpoint (no auth required)
app.get('/health', async (_req, res) => {
  const health = await checkHealth();
  res.status(health.ok ? 200 : 503).json(health);
});

// MCP endpoint with auth
app.post('/mcp', authMiddleware, async (req, res) => {
  logger.info({ path: '/mcp', method: 'POST' }, 'MCP request received');

  try {
    const sessionId = (req.headers['mcp-session-id'] as string) || randomUUID();
    let transport = transports.get(sessionId);

    if (!transport) {
      transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => sessionId,
      });
      transports.set(sessionId, transport);
      await mcp.connect(transport);
      logger.info({ sessionId }, 'New MCP session created');
    }

    await transport.handleRequest(req, res, req.body);
  } catch (error) {
    logger.error({ error }, 'MCP request failed');
    res.status(500).json({ error: 'Internal server error' });
  }
});

// SSE endpoint for server notifications
app.get('/mcp', authMiddleware, async (req, res) => {
  const sessionId = req.headers['mcp-session-id'] as string;

  if (!sessionId) {
    res.status(400).json({ error: 'Session ID required for SSE' });
    return;
  }

  const transport = transports.get(sessionId);
  if (!transport) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }

  logger.info({ sessionId }, 'SSE connection established');
  await transport.handleRequest(req, res);
});

// Session cleanup endpoint
app.delete('/mcp/sessions/:sessionId', authMiddleware, async (req, res) => {
  const { sessionId } = req.params;
  const transport = transports.get(sessionId);

  if (transport) {
    await transport.close();
    transports.delete(sessionId);
    logger.info({ sessionId }, 'Session closed');
    res.status(200).json({ message: 'Session closed' });
  } else {
    res.status(404).json({ error: 'Session not found' });
  }
});

// Graceful shutdown
async function shutdown(signal: string): Promise<void> {
  logger.info({ signal }, 'Shutdown signal received');

  for (const [sessionId, transport] of transports) {
    await transport.close();
    logger.info({ sessionId }, 'Session closed during shutdown');
  }
  transports.clear();

  await closePool();
  process.exit(0);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Start server
async function main(): Promise<void> {
  // Health check on startup
  const health = await checkHealth();
  if (!health.ok) {
    logger.error('Database health check failed on startup');
    process.exit(1);
  }
  logger.info({ latencyMs: health.latencyMs }, 'Database connected');

  if (config.https.enabled) {
    const tlsOptions = {
      cert: fs.readFileSync(config.https.certFile),
      key: fs.readFileSync(config.https.keyFile),
    };
    https.createServer(tlsOptions, app).listen(config.http.port, () => {
      logger.info({ port: config.http.port }, 'MCP HTTPS server started');
    });
  } else {
    app.listen(config.http.port, () => {
      logger.info({ port: config.http.port }, 'MCP HTTP server started');
    });
  }
}

main().catch((error) => {
  logger.error({ error }, 'Fatal error');
  process.exit(1);
});
