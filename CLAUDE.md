# Enterprise Authentication Testing Platform

## Project Overview

A Docker-based infrastructure for testing enterprise WiFi authentication and SAML SSO integration. Five independent, modular services work together to provide a complete authentication ecosystem.

### Services

| Service | Purpose | Ports |
|---------|---------|-------|
| **certbot** | SSL/TLS certificate management (Let's Encrypt) | 80 |
| **ldap** | OpenLDAP directory service | 389, 636 |
| **freeradius** | RADIUS authentication (EAP-TLS, PEAP, etc.) | 1812-1813/UDP, 2083/TCP |
| **keycloak** | SAML 2.0 Identity Provider | 8080, 8443 |
| **mail** | Receive-only mail server | 25, 993 |

### Architecture

```
┌─────────────┐
│   Certbot   │──► Let's Encrypt Certificates
│  (Port 80)  │           │
└─────────────┘           │
        ┌─────────────────┼─────────────────┬─────────────┐
        ▼                 ▼                 ▼             ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐ ┌───────────┐
│   OpenLDAP  │◄──│  Keycloak   │   │ FreeRADIUS  │ │Mail Server│
│ (389, 636)  │   │(8080, 8443) │   │(1812-13,2083)││ (25, 993) │
└─────────────┘   └─────────────┘   └─────────────┘ └───────────┘
                  User Federation
```

---

## Code Review Guidelines

### Core Principles

#### Simplicity First
- Choose the simplest solution that works
- Avoid abstractions until you have 3+ concrete use cases
- Delete code rather than comment it out
- One responsibility per function/class

#### Fail Fast, Fail Loud
- Validate at system boundaries (user input, external APIs), trust internal code
- Let the code fail immediately when inputs are invalid
- Use language built-ins for type checking
- Crash early rather than propagate bad state

#### Consistency Over Cleverness
- Same patterns for same problems
- If you solve authentication one way, solve it the same way everywhere
- Consistent naming conventions throughout the codebase
- Follow existing code style in the file you're editing

#### Simple Logging
- Log errors and important state changes, not every operation
- No verbose debug logging in production code
- Simple, structured output when necessary
- Trust stack traces for debugging

#### No Redundant Validation
- Don't validate inputs that the language/framework already validates
- Trust your dependencies to work or fail appropriately
- Remove code that checks for "impossible" conditions

### What to Look For

#### ✅ Approve
- Direct, obvious implementations
- Code that follows existing patterns in the codebase
- Minimal abstractions
- Clear, descriptive variable/function names
- Removal of unnecessary code

#### ❌ Request Changes
- Over-abstraction (interfaces with single implementations)
- Redundant validation of already-validated inputs
- Verbose debug logging in production paths
- Different patterns for the same type of problem
- Security vulnerabilities (injection, XSS, hardcoded secrets)

### Review Checklist

1. **Is this the simplest approach?** Can it be done with fewer lines/files/abstractions?
2. **Does it follow existing patterns?** Look for similar code elsewhere in the codebase
3. **Does it fail fast?** Errors should surface immediately, not be swallowed
4. **Is validation appropriate?** Validate at boundaries, trust internal code
5. **Can any code be deleted?** Less code is better code
6. **Is it secure?** No injection vulnerabilities, secrets in config not code

### Examples

#### Good
```javascript
function createUser(email, password) {
  return db.users.create({ email, password });
}
```

#### Bad
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

### Remember
- Code should be boring and predictable
- When in doubt, delete it
- Trust your tools and dependencies
- Consistency beats perfection
- Simple failures are better than complex success handling

---

## README Documentation Guidelines

Each service directory should have a README.md that follows this structure:

### Required Sections

1. **Title and Purpose** - One-line description of what the service does
2. **User Flow** - ASCII diagram with numbered steps and outcomes
3. **Prerequisites** - What must be set up before this service
4. **Quick Start** - Minimal steps to get running
5. **Configuration** - Environment variables and their purpose
6. **Usage** - Common commands and operations

### User Flow Diagram

Include a user flow diagram showing how requests move through the system. Use ASCII art for portability:

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER FLOW DIAGRAM                         │
└─────────────────────────────────────────────────────────────────┘

Step 1: Certificate Setup
┌──────┐    ┌─────────┐    ┌──────────────┐
│ User │───►│ Certbot │───►│ Let's Encrypt│
└──────┘    └─────────┘    └──────────────┘
   │              │
   │              ▼
   │        ┌───────────┐
   │        │ Certs     │
   │        │ Generated │
   │        └───────────┘

Step 2: LDAP Authentication
┌──────┐    ┌─────────┐    ┌──────────┐
│ User │───►│ Client  │───►│ OpenLDAP │
└──────┘    │ (ldap-  │    │ (389/636)│
            │ search) │    └──────────┘
            └─────────┘         │
                                ▼
                          ┌──────────┐
                          │ User     │
                          │ Verified │
                          └──────────┘

Step 3: WiFi/RADIUS Authentication
┌──────┐    ┌─────────┐    ┌──────────┐
│ User │───►│ WiFi AP │───►│FreeRADIUS│
└──────┘    └─────────┘    │(1812/UDP)│
                           └──────────┘
                                │
                                ▼
                          ┌──────────┐
                          │ Access   │
                          │ Granted  │
                          └──────────┘

Step 4: SAML SSO Authentication
┌──────┐    ┌─────────┐    ┌──────────┐    ┌──────────┐
│ User │───►│ Web App │───►│ Keycloak │───►│ OpenLDAP │
└──────┘    │  (SP)   │    │  (IdP)   │    └──────────┘
            └─────────┘    │  (8443)  │         │
                           └──────────┘         │
                                │               ▼
                                │         ┌──────────┐
                                ▼         │ User     │
                          ┌──────────┐    │ Verified │
                          │ SAML     │◄───└──────────┘
                          │ Assertion│
                          └──────────┘
                                │
                                ▼
                          ┌──────────┐
                          │ User     │
                          │ Logged In│
                          └──────────┘
```

### Diagram Requirements

- Use ASCII box drawing characters for portability
- Number each step in the flow
- Show the direction of data/request flow with arrows
- Label each component with its port or protocol
- End each flow with the outcome (success state)

### Writing Style

- Be concise - no filler text
- Use command examples that can be copy-pasted
- Show expected output where helpful
- Link to other service READMEs when there are dependencies
- No emojis unless explicitly requested

### README Review Checklist

When reviewing README changes, evaluate from an **overall documentation perspective**:

1. **Accuracy Check**
   - Does the diagram reflect actual service relationships?
   - Are port numbers and protocols correct?
   - Do the commands actually work?

2. **Consistency Across READMEs**
   - Same section order as other service READMEs?
   - Same section names? (e.g., "User Flow" not "Architecture", "Commands" not "Management Commands")
   - Same table formats for configuration and commands?
   - Same diagram style (ASCII boxes, numbered steps, outcomes)?

3. **Cross-Reference Integrity**
   - If service A references service B, does B's README match?
   - Are shared concepts (certificates, LDAP users) described consistently?
   - Do Quick Start sequences align with actual deployment order?

4. **Information Hierarchy**
   - Root README → Overview and Quick Start for all services
   - Service README → Detailed setup for that service only
   - No duplication between root and service READMEs

5. **Staleness Check**
   - Does the README match current docker-compose.yml?
   - Are environment variables in sync with .env.example?
   - Do Makefile targets match documented commands?

#### When to Update Multiple READMEs

| Change Type | Update Required |
|-------------|-----------------|
| New service added | Root README + new service README |
| Port change | Service README + root Architecture diagram |
| New environment variable | Service README Configuration table |
| Dependency change | Both dependent and dependency READMEs |
| Certificate flow change | certbot + all TLS-using service READMEs |

---

## Git Workflow Guidelines

### Branch Strategy

All changes must be made in feature branches. Never commit directly to `main`.

```
main (protected)
  │
  ├── feature/add-user-attributes
  ├── feature/radius-eap-ttls
  ├── fix/ldap-connection-timeout
  └── chore/update-keycloak-version
```

### Branch Naming

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feature/` | New functionality | `feature/add-saml-logout` |
| `fix/` | Bug fixes | `fix/cert-renewal-loop` |
| `chore/` | Maintenance, updates | `chore/upgrade-freeradius` |
| `docs/` | Documentation only | `docs/update-readme` |

### Development Workflow

```
Step 1: Create Branch
┌──────────┐    ┌─────────────────────┐
│   main   │───►│ git checkout -b     │
└──────────┘    │ feature/my-feature  │
                └─────────────────────┘

Step 2: Make Changes & Commit
┌─────────────────────┐    ┌─────────────────┐
│ Edit files          │───►│ git add .       │
└─────────────────────┘    │ git commit -m   │
                           │ "Add feature X" │
                           └─────────────────┘

Step 3: Push & Create PR
┌─────────────────────┐    ┌─────────────────┐
│ git push origin     │───►│ Create PR on    │
│ feature/my-feature  │    │ GitHub/GitLab   │
└─────────────────────┘    └─────────────────┘

Step 4: Review & Merge
┌─────────────────────┐    ┌─────────────────┐
│ PR Review           │───►│ Merge to main   │
│ (see checklist)     │    └─────────────────┘
└─────────────────────┘
```

### Pull Request Guidelines

#### Before Creating PR

1. Test your changes locally (`make init`, `make test` where applicable)
2. Ensure all services still work together
3. Update relevant README if behavior changes

#### PR Review Checklist

When reviewing a PR, evaluate from an **overall system perspective**:

1. **Compatibility Check**
   - Does this change break existing functionality?
   - Are other services affected? (e.g., LDAP schema changes affect Keycloak and FreeRADIUS)
   - Do configuration files need updates in multiple services?

2. **Cross-Service Impact**
   - Certificate changes → Check all TLS-dependent services
   - LDAP schema changes → Check Keycloak federation and FreeRADIUS user lookups
   - Port changes → Update docker-compose files and documentation
   - Environment variable changes → Update all affected .env.example files

3. **Integration Testing**
   - Can a fresh deployment still complete successfully?
   - Do the Makefile workflows still work end-to-end?

4. **Documentation**
   - Are READMEs updated to reflect changes?
   - Are new environment variables documented?

#### Merge Requirements

- At least one approval from a reviewer
- All discussions resolved
- No merge conflicts with `main`
- CI checks pass (if configured)

### Commit Messages

Use clear, imperative mood:

```
# Good
Add EAP-TTLS support to FreeRADIUS
Fix certificate path in Keycloak config
Update LDAP test users with new attributes

# Bad
Added stuff
Fixed bug
WIP
```
