import { pool } from '../db/pool.js';
import { logger } from '../logger.js';
import {
  limitSchema,
  nasSchema,
  timeRangeSchema,
  type LimitInput,
  type NasInput,
  type TimeRangeInput,
} from './schemas.js';

export async function radiusAcctRecent(input: unknown): Promise<string> {
  const { limit } = limitSchema.parse(input);
  logger.info({ tool: 'radius_acct_recent', limit }, 'Executing query');

  const result = await pool.query(
    `SELECT acctstarttime, username, nasidentifier,
            callingstationid, calledstationid,
            acctstoptime, acctterminatecause,
            acctinputoctets, acctoutputoctets
     FROM radacct
     ORDER BY acctstarttime DESC
     LIMIT $1`,
    [limit]
  );

  return JSON.stringify(result.rows, null, 2);
}

export async function radiusActiveSessions(input: unknown): Promise<string> {
  logger.info({ tool: 'radius_active_sessions' }, 'Executing query');

  const result = await pool.query(
    `SELECT acctstarttime, username, nasidentifier,
            callingstationid, calledstationid,
            acctinputoctets, acctoutputoctets
     FROM radacct
     WHERE acctstoptime IS NULL
     ORDER BY acctstarttime DESC`
  );

  return JSON.stringify(result.rows, null, 2);
}

export async function radiusByNas(input: unknown): Promise<string> {
  const { nas_identifier } = nasSchema.parse(input);
  logger.info({ tool: 'radius_by_nas', nas_identifier }, 'Executing query');

  const [auth, acct] = await Promise.all([
    pool.query(
      `SELECT authdate, username, reply, callingstationid
       FROM radpostauth
       WHERE nasidentifier = $1
       ORDER BY authdate DESC LIMIT 20`,
      [nas_identifier]
    ),
    pool.query(
      `SELECT acctstarttime, username, callingstationid, acctstoptime
       FROM radacct
       WHERE nasidentifier = $1
       ORDER BY acctstarttime DESC LIMIT 20`,
      [nas_identifier]
    ),
  ]);

  return JSON.stringify({ auth: auth.rows, acct: acct.rows }, null, 2);
}

export async function radiusBandwidthTop(input: unknown): Promise<string> {
  const { hours, limit } = timeRangeSchema.parse(input);
  logger.info({ tool: 'radius_bandwidth_top', hours, limit }, 'Executing query');

  const result = await pool.query(
    `SELECT username,
            SUM(acctinputoctets) as total_input,
            SUM(acctoutputoctets) as total_output,
            SUM(acctinputoctets + acctoutputoctets) as total_bytes,
            COUNT(*) as session_count
     FROM radacct
     WHERE acctstarttime > NOW() - INTERVAL '1 hour' * $1
     GROUP BY username
     ORDER BY total_bytes DESC
     LIMIT $2`,
    [hours, limit]
  );

  return JSON.stringify(result.rows, null, 2);
}
