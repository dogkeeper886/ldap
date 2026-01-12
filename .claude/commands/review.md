Review the file or code provided according to CLAUDE.md guidelines.

Check against:

1. **Code Review Guidelines** (if reviewing code):
   - Simplicity First - Is this the simplest solution?
   - Fail Fast - Validate at boundaries, trust internal code?
   - Consistency - Same patterns for same problems?
   - Simple Logging - No verbose debug logging in production?
   - No Redundant Validation - Trust framework validations?
   - Security - No injection vulnerabilities, secrets in config not code?

2. **README Documentation Guidelines** (if reviewing README):
   - Has required sections: Title/Purpose, User Flow, Prerequisites, Quick Start, Configuration, Usage?
   - User Flow Diagram with ASCII art, numbered steps, outcomes?
   - Same section order and names as other service READMEs?
   - Concise writing, copy-pasteable commands?

3. **Git Workflow** (if reviewing PR/commits):
   - Branch naming follows convention (feature/, fix/, chore/, docs/)?
   - Commit messages use imperative mood?
   - Cross-service compatibility considered?

Provide specific feedback on what passes and what needs changes.

$ARGUMENTS
