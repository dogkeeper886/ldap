import { z } from 'zod';

export const replyAttributeSchema = z.object({
  attribute: z.string().min(1).max(64).refine(
    (val) => val.toLowerCase() !== 'session-timeout',
    { message: 'Use session_timeout parameter instead of Session-Timeout attribute' }
  ),
  op: z.enum([':=', '=', '+=', '-=', '==']).default('='),
  value: z.string().max(253),
});

export type ReplyAttribute = z.infer<typeof replyAttributeSchema>;

export const createUserSchema = z.object({
  username: z.string().min(1).max(64).regex(/^[a-zA-Z0-9._-]+$/),
  password: z.string().min(4).max(128),
  groups: z.array(z.string()).optional(),
  session_timeout: z.coerce.number().int().positive().max(86400).optional(),
  reply_attributes: z.array(replyAttributeSchema).max(20).optional(),
});

export const updateUserSchema = z.object({
  username: z.string().min(1).max(64),
  password: z.string().min(4).max(128).optional(),
  groups: z.array(z.string()).optional(),
  session_timeout: z.coerce.number().int().positive().max(86400).optional(),
  enabled: z.boolean().optional(),
  reply_attributes: z.array(replyAttributeSchema).max(20).optional(),
});

export const listUsersSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
  search: z.string().max(64).optional(),
});

export const userIdentifierSchema = z.object({
  username: z.string().min(1).max(64),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;
export type UpdateUserInput = z.infer<typeof updateUserSchema>;
export type ListUsersInput = z.infer<typeof listUsersSchema>;
export type UserIdentifierInput = z.infer<typeof userIdentifierSchema>;
