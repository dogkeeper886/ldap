import { pool } from '../db/pool.js';
import { logger } from '../logger.js';
import {
  limitSchema,
  macSchema,
  usernameSchema,
  timeRangeSchema,
  type LimitInput,
  type MacInput,
  type UsernameInput,
  type TimeRangeInput,
} from './schemas.js';

export async function radiusAuthRecent(input: unknown): Promise<string> {
  const { limit } = limitSchema.parse(input);
  logger.info({ tool: 'radius_auth_recent', limit }, 'Executing query');

  const result = await pool.query(
    `SELECT authdate, username, reply, nasidentifier,
            nasipaddress, calledstationid, callingstationid
     FROM radpostauth
     ORDER BY authdate DESC
     LIMIT $1`,
    [limit]
  );

  return JSON.stringify(result.rows, null, 2);
}

export async function radiusFailedAuth(input: unknown): Promise<string> {
  const { hours, limit } = timeRangeSchema.parse(input);
  logger.info({ tool: 'radius_failed_auth', hours, limit }, 'Executing query');

  const result = await pool.query(
    `SELECT authdate, username, reply, nasidentifier, callingstationid
     FROM radpostauth
     WHERE reply != 'Access-Accept'
       AND authdate > NOW() - INTERVAL '1 hour' * $1
     ORDER BY authdate DESC
     LIMIT $2`,
    [hours, limit]
  );

  return JSON.stringify(result.rows, null, 2);
}

export async function radiusByMac(input: unknown): Promise<string> {
  const { mac } = macSchema.parse(input);
  const macPattern = `%${mac.replace(/[:\-]/g, '')}%`;
  logger.info({ tool: 'radius_by_mac', mac }, 'Executing query');

  const [auth, acct] = await Promise.all([
    pool.query(
      `SELECT authdate, username, reply, nasidentifier
       FROM radpostauth
       WHERE REPLACE(REPLACE(callingstationid, '-', ''), ':', '') ILIKE $1
       ORDER BY authdate DESC LIMIT 10`,
      [macPattern]
    ),
    pool.query(
      `SELECT acctstarttime, username, nasidentifier, acctstoptime, acctterminatecause
       FROM radacct
       WHERE REPLACE(REPLACE(callingstationid, '-', ''), ':', '') ILIKE $1
       ORDER BY acctstarttime DESC LIMIT 10`,
      [macPattern]
    ),
  ]);

  return JSON.stringify({ auth: auth.rows, acct: acct.rows }, null, 2);
}

export async function radiusByUser(input: unknown): Promise<string> {
  const { username } = usernameSchema.parse(input);
  logger.info({ tool: 'radius_by_user', username }, 'Executing query');

  const [auth, acct] = await Promise.all([
    pool.query(
      `SELECT authdate, reply, nasidentifier, callingstationid
       FROM radpostauth
       WHERE username = $1
       ORDER BY authdate DESC LIMIT 10`,
      [username]
    ),
    pool.query(
      `SELECT acctstarttime, nasidentifier, callingstationid, acctstoptime, acctterminatecause
       FROM radacct
       WHERE username = $1
       ORDER BY acctstarttime DESC LIMIT 10`,
      [username]
    ),
  ]);

  return JSON.stringify({ auth: auth.rows, acct: acct.rows }, null, 2);
}
