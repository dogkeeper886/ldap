import { pool } from './pool.js';

export interface HealthStatus {
  ok: boolean;
  latencyMs: number;
}

export async function checkHealth(): Promise<HealthStatus> {
  const start = Date.now();
  try {
    await pool.query('SELECT 1');
    return { ok: true, latencyMs: Date.now() - start };
  } catch {
    return { ok: false, latencyMs: Date.now() - start };
  }
}
