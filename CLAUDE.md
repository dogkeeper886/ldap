# Code Review Guidelines

## Core Principles

### Simplicity First
- Choose the simplest solution that works
- Avoid abstractions until you have 3+ concrete use cases
- Delete code rather than comment it out
- One responsibility per function/class

### Fail Fast, Fail Loud
- No defensive programming or extensive validation
- Let the code fail immediately when inputs are invalid
- Use language built-ins for type checking
- Crash early rather than propagate bad state

### Consistency Over Cleverness
- Same patterns for same problems
- If you solve authentication one way, solve it the same way everywhere
- Consistent naming conventions throughout the codebase
- Follow existing code style in the file you're editing

### No Complex Debug/Logging
- Avoid complicated logging infrastructure
- No elaborate debug systems or verbose error messages
- Simple console output when absolutely necessary
- Trust stack traces for debugging

### No Health Checks or Redundant Validation
- Don't validate inputs that the language/framework already validates
- No "health check" endpoints or status monitoring code
- Trust your dependencies to work or fail appropriately
- Remove code that checks for "impossible" conditions

## What to Look For

### ✅ Approve
- Direct, obvious implementations
- Code that follows existing patterns in the codebase
- Minimal abstractions
- Clear, descriptive variable/function names
- Removal of unnecessary code

### ❌ Request Changes
- Over-abstraction (interfaces with single implementations)
- Defensive validation of already-validated inputs
- Health checks, status endpoints, or monitoring code
- Complex logging or debugging infrastructure
- Different patterns for the same type of problem
- Code that tries to "be safe" instead of being correct

## Review Checklist

1. **Is this the simplest approach?** Can it be done with fewer lines/files/abstractions?
2. **Does it follow existing patterns?** Look for similar code elsewhere in the codebase
3. **Does it fail fast?** No graceful degradation or fallback logic
4. **Is validation necessary?** Remove checks that duplicate language/framework validation
5. **Can any code be deleted?** Less code is better code
6. **Is logging/debugging simple?** No complex debug infrastructure

## Examples

### Good
```javascript
function createUser(email, password) {
  return db.users.create({ email, password });
}
```

### Bad
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
- Trust your tools and dependencies
- Consistency beats perfection
- Simple failures are better than complex success handling