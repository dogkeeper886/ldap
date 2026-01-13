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

## Remember
- Code should be boring and predictable
- When in doubt, delete it
- Trust internal code, verify external input
- Consistency beats perfection
- Simple code with good logging beats complex defensive code
