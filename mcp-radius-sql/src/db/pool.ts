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

export async function closePool(): Promise<void> {
  logger.info('Closing database pool');
  await pool.end();
}
