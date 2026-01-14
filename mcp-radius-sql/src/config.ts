import { z } from 'zod';
import 'dotenv/config';

const configSchema = z.object({
  http: z.object({
    port: z.coerce.number().int().positive().default(3000),
    token: z.string().min(32, 'MCP_TOKEN must be at least 32 characters'),
  }),
  https: z.object({
    enabled: z.coerce.boolean().default(false),
    certFile: z.string().default('/app/certs/fullchain.pem'),
    keyFile: z.string().default('/app/certs/privkey.pem'),
  }),
  postgres: z.object({
    host: z.string().min(1),
    port: z.coerce.number().int().positive().default(5432),
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
    http: {
      port: process.env.HTTP_PORT,
      token: process.env.MCP_TOKEN,
    },
    https: {
      enabled: process.env.HTTPS_ENABLED,
      certFile: process.env.TLS_CERT_FILE,
      keyFile: process.env.TLS_KEY_FILE,
    },
    postgres: {
      host: process.env.POSTGRES_HOST,
      port: process.env.POSTGRES_PORT,
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
export type Config = z.infer<typeof configSchema>;
