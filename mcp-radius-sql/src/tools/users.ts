import { pool } from '../db/pool.js';
import { logger } from '../logger.js';
import {
  createUserSchema,
  updateUserSchema,
  listUsersSchema,
  userIdentifierSchema,
  type CreateUserInput,
  type UpdateUserInput,
  type ListUsersInput,
  type UserIdentifierInput,
} from './user-schemas.js';

export async function createUser(input: unknown): Promise<string> {
  const { username, password, groups, session_timeout } = createUserSchema.parse(input);
  logger.info({ tool: 'radius_user_create', username }, 'Creating user');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Check if user already exists
    const existing = await client.query(
      'SELECT 1 FROM radcheck WHERE username = $1 LIMIT 1',
      [username]
    );
    if (existing.rows.length > 0) {
      throw new Error(`User '${username}' already exists`);
    }

    // Insert password into radcheck
    await client.query(
      `INSERT INTO radcheck (username, attribute, op, value)
       VALUES ($1, 'Cleartext-Password', ':=', $2)`,
      [username, password]
    );

    // Insert session timeout into radreply if provided
    if (session_timeout) {
      await client.query(
        `INSERT INTO radreply (username, attribute, op, value)
         VALUES ($1, 'Session-Timeout', '=', $2)`,
        [username, session_timeout.toString()]
      );
    }

    // Insert group memberships
    if (groups && groups.length > 0) {
      for (let i = 0; i < groups.length; i++) {
        await client.query(
          `INSERT INTO radusergroup (username, groupname, priority)
           VALUES ($1, $2, $3)`,
          [username, groups[i], i + 1]
        );
      }
    }

    await client.query('COMMIT');
    logger.info({ username }, 'User created');
    return JSON.stringify({ success: true, username, message: 'User created' });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function getUser(input: unknown): Promise<string> {
  const { username } = userIdentifierSchema.parse(input);
  logger.info({ tool: 'radius_user_get', username }, 'Getting user');

  const [checkResult, replyResult, groupResult] = await Promise.all([
    pool.query(
      `SELECT attribute, op, value FROM radcheck
       WHERE username = $1 AND attribute != 'Cleartext-Password'`,
      [username]
    ),
    pool.query(
      `SELECT attribute, op, value FROM radreply WHERE username = $1`,
      [username]
    ),
    pool.query(
      `SELECT groupname, priority FROM radusergroup
       WHERE username = $1 ORDER BY priority`,
      [username]
    ),
  ]);

  // Check if user exists (check for password attribute)
  const existsResult = await pool.query(
    `SELECT 1 FROM radcheck WHERE username = $1 LIMIT 1`,
    [username]
  );
  if (existsResult.rows.length === 0) {
    return JSON.stringify({ error: `User '${username}' not found` });
  }

  // Check if user is disabled
  const disabledResult = await pool.query(
    `SELECT 1 FROM radcheck
     WHERE username = $1 AND attribute = 'Auth-Type' AND value = 'Reject'`,
    [username]
  );
  const enabled = disabledResult.rows.length === 0;

  const user = {
    username,
    enabled,
    check_attributes: checkResult.rows,
    reply_attributes: replyResult.rows,
    groups: groupResult.rows.map(r => r.groupname),
  };

  return JSON.stringify(user, null, 2);
}

export async function updateUser(input: unknown): Promise<string> {
  const { username, password, groups, session_timeout, enabled } = updateUserSchema.parse(input);
  logger.info({ tool: 'radius_user_update', username }, 'Updating user');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Check if user exists
    const existing = await client.query(
      'SELECT 1 FROM radcheck WHERE username = $1 LIMIT 1',
      [username]
    );
    if (existing.rows.length === 0) {
      throw new Error(`User '${username}' not found`);
    }

    // Update password if provided
    if (password !== undefined) {
      await client.query(
        `UPDATE radcheck SET value = $2
         WHERE username = $1 AND attribute = 'Cleartext-Password'`,
        [username, password]
      );
    }

    // Update session timeout if provided
    if (session_timeout !== undefined) {
      await client.query(
        `DELETE FROM radreply WHERE username = $1 AND attribute = 'Session-Timeout'`,
        [username]
      );
      await client.query(
        `INSERT INTO radreply (username, attribute, op, value)
         VALUES ($1, 'Session-Timeout', '=', $2)`,
        [username, session_timeout.toString()]
      );
    }

    // Update groups if provided
    if (groups !== undefined) {
      await client.query(
        `DELETE FROM radusergroup WHERE username = $1`,
        [username]
      );
      for (let i = 0; i < groups.length; i++) {
        await client.query(
          `INSERT INTO radusergroup (username, groupname, priority)
           VALUES ($1, $2, $3)`,
          [username, groups[i], i + 1]
        );
      }
    }

    // Update enabled state if provided
    if (enabled !== undefined) {
      // Remove any existing Auth-Type Reject
      await client.query(
        `DELETE FROM radcheck WHERE username = $1 AND attribute = 'Auth-Type'`,
        [username]
      );
      if (!enabled) {
        // Add Auth-Type Reject to disable user
        await client.query(
          `INSERT INTO radcheck (username, attribute, op, value)
           VALUES ($1, 'Auth-Type', ':=', 'Reject')`,
          [username]
        );
      }
    }

    await client.query('COMMIT');
    logger.info({ username }, 'User updated');
    return JSON.stringify({ success: true, username, message: 'User updated' });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function deleteUser(input: unknown): Promise<string> {
  const { username } = userIdentifierSchema.parse(input);
  logger.info({ tool: 'radius_user_delete', username }, 'Deleting user');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Check if user exists
    const existing = await client.query(
      'SELECT 1 FROM radcheck WHERE username = $1 LIMIT 1',
      [username]
    );
    if (existing.rows.length === 0) {
      throw new Error(`User '${username}' not found`);
    }

    // Delete from all tables
    await Promise.all([
      client.query('DELETE FROM radcheck WHERE username = $1', [username]),
      client.query('DELETE FROM radreply WHERE username = $1', [username]),
      client.query('DELETE FROM radusergroup WHERE username = $1', [username]),
    ]);

    await client.query('COMMIT');
    logger.info({ username }, 'User deleted');
    return JSON.stringify({ success: true, username, message: 'User deleted' });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function listUsers(input: unknown): Promise<string> {
  const { limit, offset, search } = listUsersSchema.parse(input);
  logger.info({ tool: 'radius_user_list', limit, offset, search }, 'Listing users');

  let query = `
    SELECT DISTINCT rc.username,
           EXISTS(SELECT 1 FROM radcheck r2
                  WHERE r2.username = rc.username
                  AND r2.attribute = 'Auth-Type' AND r2.value = 'Reject') as disabled,
           ARRAY(SELECT groupname FROM radusergroup
                 WHERE username = rc.username ORDER BY priority) as groups
    FROM radcheck rc
    WHERE rc.attribute = 'Cleartext-Password'
  `;
  const params: (string | number)[] = [];
  let paramIndex = 1;

  if (search) {
    query += ` AND rc.username ILIKE $${paramIndex}`;
    params.push(`%${search}%`);
    paramIndex++;
  }

  query += ` ORDER BY rc.username LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
  params.push(limit, offset);

  const result = await pool.query(query, params);

  const users = result.rows.map(row => ({
    username: row.username,
    enabled: !row.disabled,
    groups: row.groups,
  }));

  // Get total count
  let countQuery = `
    SELECT COUNT(DISTINCT username) as total
    FROM radcheck WHERE attribute = 'Cleartext-Password'
  `;
  const countParams: string[] = [];
  if (search) {
    countQuery += ' AND username ILIKE $1';
    countParams.push(`%${search}%`);
  }
  const countResult = await pool.query(countQuery, countParams);
  const total = parseInt(countResult.rows[0].total, 10);

  return JSON.stringify({ users, total, limit, offset }, null, 2);
}
