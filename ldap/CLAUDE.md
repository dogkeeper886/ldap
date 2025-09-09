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

**Add user to `scripts/setup-users.sh`:**
- Add user creation block
- Add password setting with `ldappasswd`
- Add to group membership

**Add password to `.env.example`:**
```bash
NEW_USER_PASSWORD=SecurePass123!
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

**Add group to `scripts/setup-users.sh`:**
- Add group creation block

**Add WiFi group to `scripts/add-msad-attributes.sh`:**
- Add group creation in WiFi groups section

## Adding New Attributes

**Add schema to `ldifs/05-msad-compat.ldif`:**
```ldif
olcAttributeTypes: ( 1.3.6.1.4.1.99999.1.X
  NAME 'attributeName'
  DESC 'Description'
  EQUALITY caseIgnoreMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )
```

**Add to `scripts/add-msad-attributes.sh`:**
- Add schema installation
- Add attribute application to users

## File Dependencies

- `06-users-with-msad.ldif` requires `05-msad-compat.ldif` to be applied first
- WiFi groups (`wifi-users`, `wifi-guests`, `wifi-admins`) must exist before adding `memberOf` attributes