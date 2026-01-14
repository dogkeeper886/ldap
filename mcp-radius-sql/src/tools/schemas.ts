import { z } from 'zod';

export const limitSchema = z.object({
  limit: z.number().int().min(1).max(100).default(20),
});

export const macSchema = z.object({
  mac: z.string().regex(
    /^([0-9A-Fa-f]{2}[:\-]){5}([0-9A-Fa-f]{2})$/,
    'Invalid MAC address format (use XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX)'
  ),
});

export const usernameSchema = z.object({
  username: z.string().min(1).max(64),
});

export const nasSchema = z.object({
  nas_identifier: z.string().min(1).max(128),
});

export const timeRangeSchema = z.object({
  hours: z.number().int().min(1).max(720).default(24),
  limit: z.number().int().min(1).max(100).default(20),
});

export type LimitInput = z.infer<typeof limitSchema>;
export type MacInput = z.infer<typeof macSchema>;
export type UsernameInput = z.infer<typeof usernameSchema>;
export type NasInput = z.infer<typeof nasSchema>;
export type TimeRangeInput = z.infer<typeof timeRangeSchema>;
