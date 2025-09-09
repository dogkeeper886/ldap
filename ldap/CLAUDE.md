# LDAP User and Attribute Management Guidelines

## Adding New Test Users

**Add user to `ldifs/02-users.ldif`:**
```ldif
dn: uid=test-user-06,ou=users,dc=example,dc=com
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: test-user-06
cn: User Full Name
sn: LastName
givenName: FirstName
displayName: Display Name - Role
mail: user@example.com
telephoneNumber: +1-555-0106
mobile: +1-555-9106
title: Job Title
ou: Department Name
departmentNumber: DEPT001
employeeNumber: EMP006
employeeType: Full-Time
description: User description
street: Address
l: City
st: State
postalCode: ZIP
preferredLanguage: en-US
# userPassword will be set via script
```

**Add user to `ldifs/06-users-with-msad.ldif`:**
```ldif
dn: uid=test-user-06,ou=users,dc=example,dc=com
changetype: modify
add: objectClass
objectClass: msadUser
-
add: sAMAccountName
sAMAccountName: test-user-06
-
add: userPrincipalName
userPrincipalName: test-user-06@example.com
-
add: memberOf
memberOf: cn=wifi-users,ou=groups,dc=example,dc=com
-
add: userAccountControl
userAccountControl: 512
```

**Add user password to `.env.example`:**
```bash
NEW_USER_06_PASSWORD=SecurePass123!
```

**Add user to `scripts/setup-users.sh`:**
```bash
docker exec openldap ldappasswd -x -H ldap://localhost \
    -D "cn=admin,$base_dn" -w "$LDAP_ADMIN_PASSWORD" \
    -s "$NEW_USER_06_PASSWORD" "uid=test-user-06,ou=users,$base_dn"
```

## Adding New Groups

**Add group to `ldifs/03-groups.ldif`:**
```ldif
dn: cn=group-name,ou=groups,dc=example,dc=com
objectClass: top
objectClass: groupOfNames
cn: group-name
member: uid=test-user-01,ou=users,dc=example,dc=com
```

**Add user to new group:**
```ldif
dn: uid=test-user-01,ou=users,dc=example,dc=com
changetype: modify
add: memberOf
memberOf: cn=group-name,ou=groups,dc=example,dc=com
```

**Note:** Groups are automatically imported by `scripts/setup-users.sh` from LDIF files

## Adding New Attributes

**Add schema to `ldifs/05-msad-compat.ldif`:**
```ldif
olcAttributeTypes: ( 1.2.840.113556.1.4.X
  NAME 'attributeName'
  DESC 'Description'
  EQUALITY caseIgnoreMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )
olcObjectClasses: ( 1.2.840.113556.1.5.X
  NAME 'customUser'
  SUP top AUXILIARY
  MAY ( attributeName ) )
```

**Apply new attribute to existing users:**
```ldif
dn: uid=test-user-01,ou=users,dc=example,dc=com
changetype: modify
add: objectClass
objectClass: customUser
-
add: attributeName
attributeName: value
```

## File Structure

- `01-organizational-units.ldif` - Creates ou=users and ou=groups
- `02-users.ldif` - User definitions
- `03-groups.ldif` - Group definitions  
- `05-msad-compat.ldif` - MS AD schema extensions
- `06-users-with-msad.ldif` - Applies MS AD attributes to users

## Group Names

Available groups in `06-users-with-msad.ldif`:
- `wifi-users` - Standard access
- `wifi-guests` - Guest access
- `wifi-admins` - Admin access
- `external-users` - Contractor access
- `executives` - VIP access

## File Dependencies

- `06-users-with-msad.ldif` requires `05-msad-compat.ldif` to be applied first
- Groups must exist before adding `memberOf` attributes
- `memberOf` is manually assigned via `ldapmodify` commands (not auto-managed)

## Script Automation

`scripts/setup-users.sh` automatically:
- Loads MS AD schema (`05-msad-compat.ldif`)
- Imports all LDIF files with domain replacement
- Sets passwords for all users via `ldappasswd`
- Applies MS AD attributes (`06-users-with-msad.ldif`)