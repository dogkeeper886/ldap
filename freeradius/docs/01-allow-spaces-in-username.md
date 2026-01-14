# Allow Spaces in Username Policy

## Problem Statement

FreeRADIUS default policy rejects usernames containing whitespace. This blocks EAP-TLS authentication when the client certificate CN contains spaces (e.g., "Client Wireless Device Certificate 98765432").

Error from logs:
```
User-Name = "Client Wireless Device Certificate 98765432"
if (&User-Name =~ / /)  -> TRUE
Rejected: User-Name contains whitespace
```

## Proposed Solution

Copy and modify the FreeRADIUS filter policy to allow spaces while keeping other security filters.

### Files to Change

| File | Action |
|------|--------|
| `docker/freeradius/config/policy.d/filter` | Create custom policy (copy from default, comment out whitespace check) |
| `docker/freeradius/Dockerfile` | Add COPY for custom policy |

### Implementation Steps

1. Create `config/policy.d/` directory
2. Copy default filter policy to `config/policy.d/filter`
3. Comment out the whitespace rejection block
4. Update Dockerfile to copy custom policy

### Policy Change

Original (reject whitespace):
```
if (&User-Name =~ / /) {
    update request {
        &Module-Failure-Message += 'Rejected: User-Name contains whitespace'
    }
    reject
}
```

Modified (allow whitespace):
```
#
#  Allow whitespace in User-Name for EAP-TLS certificate CNs
#
#if (&User-Name =~ / /) {
#    update request {
#        &Module-Failure-Message += 'Rejected: User-Name contains whitespace'
#    }
#    reject
#}
```

### Security Filters Retained

The following filters remain active:
- Reject multiple @ symbols (e.g., `user@site.com@site.com`)
- Reject double dots (e.g., `user@site..com`)
- Reject realm without dot separator
- Reject realm ending with dot
- Reject realm beginning with dot

### Dockerfile Addition

```dockerfile
# Copy custom policy files
COPY config/policy.d/filter /etc/raddb/policy.d/filter
```

## Key Decisions

1. **Modify policy vs change certificate CN**: Chose policy modification because:
   - Certificate CNs with spaces are valid per X.509
   - Changing existing certificates requires re-issuance
   - Policy change is minimal and reversible

2. **Comment out vs delete**: Chose to comment out for:
   - Clear documentation of what was disabled
   - Easy to revert if needed

## Testing

After implementation:
1. Rebuild: `make build`
2. Deploy: `make deploy`
3. Verify authentication succeeds for certificates with spaces in CN
