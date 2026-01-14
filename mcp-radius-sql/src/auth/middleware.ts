import { Request, Response, NextFunction } from 'express';
import { timingSafeEqual } from 'node:crypto';
import { config } from '../config.js';
import { logger } from '../logger.js';

export function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    logger.warn({ path: req.path }, 'Missing authorization header');
    res.status(401)
      .set('WWW-Authenticate', 'Bearer realm="MCP Server"')
      .json({ error: 'Unauthorized' });
    return;
  }

  if (!authHeader.startsWith('Bearer ')) {
    logger.warn({ path: req.path }, 'Invalid authorization header format');
    res.status(401).json({ error: 'Invalid authorization format' });
    return;
  }

  const token = authHeader.slice(7);

  if (!safeCompare(token, config.http.token)) {
    logger.warn({ path: req.path }, 'Invalid token');
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  next();
}

function safeCompare(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);

  if (bufA.length !== bufB.length) {
    return false;
  }

  return timingSafeEqual(bufA, bufB);
}
