import { pino } from 'pino';
import { config } from './config.js';

export const logger = pino({
  level: config.log.level,
  formatters: {
    level: (label: string) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
