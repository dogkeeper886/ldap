# Code Review Guidelines

## Core Principles

### Simplicity First
- Choose the simplest solution that works
- Avoid abstractions until you have 3+ concrete use cases
- Delete code rather than comment it out
- One responsibility per function/class

### Fail Fast, Fail Loud
- Let the code fail immediately when inputs are invalid
- Use language built-ins for type checking
- Crash early rather than propagate bad state
- Don't catch exceptions just to log and re-throw

### Validate at Boundaries
- Validate user input and external API responses (security requirement)
- Don't re-validate data passed between internal functions
- Trust internal interfaces, verify external ones

### Consistency Over Cleverness
- Same patterns for same problems
- If you solve authentication one way, solve it the same way everywhere
- Consistent naming conventions throughout the codebase
- Follow existing code style in the file you're editing

### Appropriate Logging
- Use structured logging with log levels (debug, info, warn, error)
- Log at system boundaries: incoming requests, outgoing calls, errors
- Don't log inside tight loops or internal helper functions
- Include context (request ID, user ID) for traceability
- Avoid logging sensitive data (passwords, tokens, PII)

### Production Readiness
- Health checks are required for containerized services (Kubernetes, Docker)
- Include liveness and readiness probes where applicable
- Handle external service failures gracefully (timeouts, retries)
- Don't over-engineer: start simple, add resilience when needed

## New Feature Guidelines

### Design Documents Required
- Before implementing a new feature, create a design document in `/docs`
- Document the original design intent, architecture decisions, and rationale
- This preserves context for future maintenance and prevents design drift
- Keep design docs simple: problem statement, proposed solution, key decisions

## What to Look For

### Approve
- Direct, obvious implementations
- Code that follows existing patterns in the codebase
- Minimal abstractions
- Clear, descriptive variable/function names
- Removal of unnecessary code
- Validation at system boundaries
- Appropriate logging at entry/exit points

### Request Changes
- Over-abstraction (interfaces with single implementations)
- Re-validation of already-validated internal data
- Logging inside loops or performance-critical paths
- Different patterns for the same type of problem
- Catching exceptions only to log and re-throw
- Files containing private information (passwords, API keys, tokens, credentials, internal URLs)

## Review Checklist

1. **Is this the simplest approach?** Can it be done with fewer lines/files/abstractions?
2. **Does it follow existing patterns?** Look for similar code elsewhere in the codebase
3. **Does it fail fast?** No swallowing errors or silent failures
4. **Is boundary validation present?** User input and external APIs should be validated
5. **Can any code be deleted?** Less code is better code
6. **Is logging appropriate?** At boundaries, not inside loops, with proper levels
7. **No private information?** Check for passwords, API keys, tokens, internal URLs, or credentials

## Examples

### Good: Clean with Boundary Validation
```javascript
function createUser(email, password) {
  // Validate at API boundary
  if (!email || !password) {
    throw new Error('Email and password required');
  }
  return db.users.create({ email, password });
}
```

### Good: Appropriate Logging
```javascript
async function processOrder(orderId) {
  log.info('Processing order', { orderId });
  const order = await db.orders.get(orderId);
  const result = await paymentService.charge(order);
  log.info('Order processed', { orderId, status: result.status });
  return result;
}
```

### Bad: Over-Logging and Redundant Validation
```javascript
function createUser(email, password) {
  logger.debug('Creating user', { email });
  
  if (!email || typeof email !== 'string') {
    logger.error('Invalid email provided');
    throw new Error('Invalid email');
  }
  if (!password || password.length < 8) {
    logger.warn('Password validation failed');
    throw new Error('Password too short');
  }
  
  try {
    const user = db.users.create({ email, password });
    logger.info('User created successfully', { userId: user.id });
    return { success: true, user };
  } catch (error) {
    logger.error('User creation failed', error);
    return { success: false, error: error.message };
  }
}
```

## MCP Server Development Guidelines

### Required Technology Stack

| Component | Library | Purpose |
|-----------|---------|---------|
| Language | TypeScript | Type safety, better tooling |
| Validation | zod | Runtime input validation |
| Logging | pino | Structured JSON logging |
| Config | dotenv + zod | Environment loading with validation |
| Testing | vitest | Fast TypeScript-native testing |

### MCP Server Requirements

1. **Configuration Validation**
   - Validate all environment variables at startup using Zod
   - Fail fast if required config is missing
   - Never use unchecked `process.env` values

2. **Health Checks**
   - Implement database/service health check
   - Check health on startup before accepting requests
   - Exit with error if health check fails

3. **Input Validation**
   - Define Zod schemas for all tool inputs
   - Validate inputs before query execution
   - Return structured validation errors

4. **Error Handling**
   - Catch and categorize errors (validation, database, unknown)
   - Log errors with context (tool name, input params)
   - Return user-friendly error messages without stack traces
   - Never expose internal error details to clients

5. **Logging**
   - Log at tool execution boundaries (start, completion, error)
   - Include context: tool name, relevant parameters
   - Never log: passwords, full query results, PII
   - Use structured logging (JSON format)

6. **Graceful Shutdown**
   - Handle SIGTERM signal
   - Close database connections cleanly
   - Log shutdown events

### MCP Server Project Structure

```
mcp-{name}/
├── package.json
├── tsconfig.json
├── .env.example
├── src/
│   ├── index.ts      # Entry point with signal handlers
│   ├── config.ts     # Zod-validated configuration
│   ├── logger.ts     # Pino logger setup
│   ├── db/           # Database connection and health
│   └── tools/        # Tool implementations with schemas
└── tests/
```

### Example: Config with Validation

```typescript
import { z } from 'zod';
import 'dotenv/config';

const schema = z.object({
  db: z.object({
    host: z.string().min(1),
    port: z.coerce.number().positive(),
    password: z.string().min(1),
  }),
});

const result = schema.safeParse({ /* env values */ });
if (!result.success) {
  console.error('Config error:', result.error.format());
  process.exit(1);
}
export const config = result.data;
```

### Example: Tool with Error Handling

```typescript
const tool = {
  handler: async (input: unknown) => {
    try {
      const validated = schema.parse(input);
      logger.info({ tool: 'name', ...validated }, 'Executing');
      const result = await query(validated);
      return { content: [{ type: 'text', text: JSON.stringify(result) }] };
    } catch (error) {
      if (error instanceof ZodError) {
        return { content: [{ type: 'text', text: `Validation: ${error.message}` }], isError: true };
      }
      logger.error({ error }, 'Tool failed');
      return { content: [{ type: 'text', text: 'Internal error' }], isError: true };
    }
  },
};
```

## Remember
- Code should be boring and predictable
- When in doubt, delete it
- Trust internal code, verify external input
- Consistency beats perfection
- Simple code with good logging beats complex defensive code
