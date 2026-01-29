# SQL-Based User Authentication Design

## Overview

This document describes the migration from file-based user authentication to SQL-based authentication in FreeRADIUS, along with MCP tools for user management.

## Problem Statement

The original file-based user management (`/etc/raddb/mods-config/files/authorize`) had limitations:

1. **No dynamic management** - Adding/removing users required file edits and service restart
2. **No API access** - Users couldn't be managed programmatically
3. **No audit trail** - Changes weren't tracked in a queryable format
4. **Scaling concerns** - File-based lookup doesn't scale well with many users

## Solution

Migrate user authentication to SQL database with MCP tools for CRUD operations.

### Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  MCP Client     │────▶│  MCP Server      │────▶│  PostgreSQL     │
│  (Claude, etc.) │     │  (radius_user_*) │     │  (radcheck, etc)│
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │  FreeRADIUS     │
                                                 │  (SQL module)   │
                                                 └─────────────────┘
```

### Database Schema

| Table | Purpose |
|-------|---------|
| `radcheck` | User check attributes (passwords, Auth-Type) |
| `radreply` | User reply attributes (Session-Timeout) |
| `radusergroup` | User-to-group membership |
| `radgroupcheck` | Group check attributes |
| `radgroupreply` | Group reply attributes (Reply-Message) |

### MCP Tools

| Tool | Description |
|------|-------------|
| `radius_user_create` | Create user with password, groups, session timeout |
| `radius_user_get` | Get user details (excludes password) |
| `radius_user_update` | Update password, groups, enabled state |
| `radius_user_delete` | Delete user from all tables |
| `radius_user_list` | List users with pagination and search |

## Design Decisions

### 1. Cleartext-Password Storage

**Decision:** Store passwords as `Cleartext-Password` attribute in `radcheck`.

**Rationale:** FreeRADIUS requires cleartext or NT-Hash for PEAP/MSCHAPv2. Cleartext is simplest and allows all auth methods. Database access is already secured via network isolation and credentials.

**Alternative considered:** NT-Hash storage - rejected because it limits auth methods to MSCHAPv2 only.

### 2. Group-Based Reply Attributes

**Decision:** Store `Reply-Message` in `radgroupreply` rather than per-user `radreply`.

**Rationale:**
- Reduces duplication
- Easier to maintain consistent messages
- Per-user attributes (like `Session-Timeout`) can still be set via `radreply`

### 3. User Disable Mechanism

**Decision:** Disable users by adding `Auth-Type := Reject` to `radcheck`.

**Rationale:** Standard FreeRADIUS pattern. The `Auth-Type` attribute with value `Reject` causes immediate authentication failure without checking password.

### 4. Transaction-Based Operations

**Decision:** All write operations use database transactions.

**Rationale:** User creation/update involves multiple tables. Transactions ensure atomicity - either all changes apply or none do.

## Migration Details

### Migrated Users

The following users were migrated from file to SQL:

| Username | Group | Special Attributes |
|----------|-------|-------------------|
| test | users | - |
| guest | guests | Session-Timeout: 3600 (via group) |
| admin | admins | - |
| contractor | contractors | Session-Timeout: 28800 (via group) |
| vip | vip | - |

### Passwords

Passwords are injected via environment variables at database initialization:

- `TEST_USER_PASSWORD`
- `GUEST_USER_PASSWORD`
- `ADMIN_USER_PASSWORD`
- `CONTRACTOR_PASSWORD`
- `VIP_PASSWORD`

## Known Behavioral Changes

### 1. Unknown User Rejection

**Previous behavior:**
```
DEFAULT Auth-Type := Reject, EAP-Message !* ANY
        Reply-Message := "Authentication denied"
```

Unknown users (not in file) received explicit rejection with "Authentication denied" message.

**New behavior:**

Unknown users fail SQL authorization silently. Authentication is still denied, but without explicit `Reply-Message`.

**Impact:** Low. Authentication still fails. Some RADIUS clients may log different error messages.

**Mitigation:** If explicit rejection messages are required, add a default group with `Auth-Type := Reject` in `radgroupcheck` and assign unknown user attempts to it via FreeRADIUS policy.

### 2. Authorization Order

**Previous:** Files module only
**New:** Files module (empty) → SQL module

FreeRADIUS default site checks files first, then SQL. Since the files module now returns no users, SQL handles all authorization.

## Security Considerations

1. **Password exposure** - `radius_user_get` explicitly excludes password from response
2. **SQL injection** - All queries use parameterized statements via pg driver
3. **Input validation** - Zod schemas validate all inputs at API boundary
4. **Transaction isolation** - Prevents partial updates on failure

## Testing

### Manual Testing Checklist

- [ ] Create user via MCP tool
- [ ] Authenticate created user via radtest
- [ ] Update user password, verify new password works
- [ ] Disable user, verify authentication fails
- [ ] Enable user, verify authentication works
- [ ] Delete user, verify authentication fails
- [ ] List users with pagination
- [ ] Search users by partial username

### Integration Test Commands

```bash
# Create user
# (via MCP tool: radius_user_create)

# Test authentication
radtest newuser password123 localhost 0 testing123

# Test with EAP
eapol_test -c eap-test.conf -s testing123
```

## Future Considerations

1. **Password hashing** - Consider NT-Hash or SSHA for password storage if auth method requirements allow
2. **Audit logging** - Add trigger-based audit table for user changes
3. **Rate limiting** - Add rate limits to MCP user management endpoints
4. **Unique constraints** - Add `UNIQUE(username, attribute)` to `radcheck` to prevent duplicate entries at DB level

## References

- [FreeRADIUS SQL Module](https://wiki.freeradius.org/modules/Rlm_sql)
- [FreeRADIUS Schema](https://github.com/FreeRADIUS/freeradius-server/tree/master/raddb/mods-config/sql)
