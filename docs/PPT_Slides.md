# LDAP WiFi Authentication Server Setup
## For Software Testers

---

## Slide 1: Title Slide
**LDAP Server Setup for WiFi Testing**
*Complete Guide for Software Testers*

- Learn how to set up LDAP server
- Test WiFi authentication
- Work with enterprise access points
- Easy step-by-step guide

---

## Slide 2: What is LDAP?
**LDAP = Lightweight Directory Access Protocol**

- Like a phone book for computers
- Stores user names and passwords
- WiFi access points use it to check if you can connect
- Think of it as a security guard for your network

**Why do we need it?**
- Test WiFi authentication
- Check if users can connect
- Make sure security works properly

---

## Slide 3: What We Will Build Today
**Complete LDAP Server Setup**

✅ LDAP server with security (TLS)
✅ Automatic SSL certificates
✅ 5 test users ready to use
✅ Works with enterprise WiFi access points
✅ Easy monitoring and testing tools
✅ Simple user management

**Perfect for testing:**
- RUCKUS One access points
- Cisco access points
- Aruba access points

---

## Slide 4: What You Need Before Starting
**Prerequisites Checklist**

**Computer Requirements:**
- Linux server (Ubuntu, CentOS, etc.)
- Docker installed
- Docker Compose installed
- Internet connection

**Network Requirements:**
- Domain name pointing to your server
- Ports 389, 636, and 80 open
- Basic command line knowledge

**Time Required:**
- Setup: 10-15 minutes
- Testing: 5-10 minutes

---

## Slide 5: Step 1 - Download and Setup
**Get the Project Files**

```bash
# Download the project
git clone https://github.com/dogkeeper886/ldap.git
cd ldap

# Create configuration file
cp .env.example .env
```

**Edit the .env file:**
```
LDAP_DOMAIN=your-domain.com
LDAP_ADMIN_PASSWORD=your-secure-password
LETSENCRYPT_EMAIL=your-email@domain.com
```

---

## Slide 6: Step 2 - One Command Setup
**Make Everything Work**

```bash
make init
```

**This one command does everything:**
1. Builds Docker containers
2. Gets SSL certificates automatically
3. Starts the LDAP server
4. Sets up the directory structure
5. Makes everything secure

**Wait time: 2-3 minutes**

---

## Slide 7: Step 3 - Create Test Users
**Add Users for Testing**

```bash
make setup-users
```

**Creates 5 test users:**
- test-user-01: IT Administrator (Password: TestPass123!)
- test-user-02: Network Engineer (Password: TestPass456!)
- test-user-03: Guest User (Password: GuestPass789!)
- test-user-04: Contractor (Password: ContractorPass321!)
- test-user-05: VIP User (Password: VipPass654!)

**Each user has:**
- Full name
- Email address
- Phone number
- Department
- Access level

---

## Slide 8: Step 4 - Add Enterprise Compatibility
**Make It Work with Enterprise Access Points**

MS AD attributes are **automatically included** with:
```bash
make setup-users
```

**Adds Microsoft Active Directory features:**
- sAMAccountName (Windows-style usernames)
- userPrincipalName (user@domain.com format)
- userAccountControl (account status)
- memberOf (group membership)

**Why this matters:**
- Many enterprise access points expect these attributes
- Makes your LDAP server work like Microsoft AD
- Compatible with more WiFi equipment

---

## Slide 9: Step 5 - Check Everything Works
**Health Check**

```bash
make health
```

**Checks 12 different things:**
✅ Docker services running
✅ Containers healthy
✅ LDAP connection works
✅ SSL certificates valid
✅ Test users exist
✅ Authentication works
✅ All attributes present
✅ System resources OK

**Result: All green = Ready to use!**

---

## Slide 10: Step 6 - Test Authentication
**Make Sure Users Can Login**

```bash
make test-auth
```

**Runs 10 different tests:**
- Valid user login ✓
- Wrong password rejected ✓
- Non-existent user rejected ✓
- Empty password rejected ✓
- SSL connection works ✓
- Admin login works ✓
- Multiple users at once ✓
- Performance is good ✓

**All tests pass = Server ready!**

---

## Slide 11: Configure Your WiFi Access Point
**RUCKUS One Configuration**

**Server Settings:**
- Server Type: LDAP/LDAPS
- Server: your-domain.com
- Port: 636 (secure) or 389 (not secure)
- Base DN: dc=your,dc=domain,dc=com
- Admin DN: cn=admin,dc=your,dc=domain,dc=com
- Admin Password: [your password]
- Search Filter: uid=%s

**For Microsoft AD compatible APs:**
- Search Filter: (sAMAccountName=%s)
- Or: (userPrincipalName=%s@your-domain.com)

---

## Slide 12: Test WiFi Authentication
**Try Connecting to WiFi**

**On your device:**
1. Connect to WiFi network
2. Choose WPA2/WPA3 Enterprise
3. Choose EAP method (PEAP or EAP-TTLS)
4. Username: test-user-01
5. Password: TestPass123!
6. Accept certificate if asked

**Result: You should connect successfully!**

---

## Slide 13: Adding New Users
**Create Custom Test Users**

**Method 1: Use the script**
```bash
# Edit the script with your user details
nano add-user.sh
chmod +x add-user.sh
./add-user.sh
```

**Method 2: Manual command**
```bash
# Add user directly
echo "dn: uid=newuser,ou=users,dc=domain,dc=com
objectClass: inetOrgPerson
uid: newuser
cn: New User
mail: newuser@domain.com" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "cn=admin,dc=domain,dc=com" -w "admin-password"
```

---

## Slide 14: Adding Custom Attributes
**Add Special Properties to Users**

**Example: Add security clearance**
```bash
echo "dn: uid=test-user-01,ou=users,dc=domain,dc=com
changetype: modify
add: description
description: High security clearance" | docker exec -i openldap ldapmodify -x -H ldap://localhost -D "cn=admin,dc=domain,dc=com" -w "admin-password"
```

**Common attributes to add:**
- employeeType: Full-Time, Contractor, Intern
- location: Building-A, Building-B, Remote
- clearanceLevel: Public, Internal, Confidential
- accessGroup: WiFi-Standard, WiFi-Guest, WiFi-Admin

---

## Slide 15: Viewing and Managing Users
**See What Users You Have**

**View all users:**
```bash
make view-ldap
```

**Search for specific user:**
```bash
docker exec openldap ldapsearch -x -H ldap://localhost -D "cn=admin,dc=domain,dc=com" -w "admin-password" -b "dc=domain,dc=com" "uid=test-user-01"
```

**Change user password:**
```bash
docker exec openldap ldappasswd -x -H ldap://localhost -D "cn=admin,dc=domain,dc=com" -w "admin-password" -s "NewPassword123!" "uid=test-user-01,ou=users,dc=domain,dc=com"
```

---

## Slide 16: Monitoring and Logs
**Check What's Happening**

**View all logs:**
```bash
make logs
```

**Follow logs in real-time:**
```bash
make logs-follow
```

**View only LDAP logs:**
```bash
make logs-ldap
```

**Check for errors:**
```bash
docker logs openldap --tail=50 | grep -i "error"
```

**What to look for:**
- Authentication attempts
- Connection errors
- Certificate renewals
- Performance issues

---

## Slide 17: Advanced Testing
**More Complex Test Scenarios**

**Performance testing:**
```bash
make test-performance
```

**TLS/SSL testing:**
```bash
make test-tls
```

**Attribute testing:**
```bash
make test-attributes
```

**Load testing (many users at once):**
```bash
# Test with 10 users connecting at same time
for i in {1..10}; do
  docker exec openldap ldapsearch -x -H ldap://localhost -D "uid=test-user-01,ou=users,dc=domain,dc=com" -w "TestPass123!" -b "" -s base &
done
```

---

## Slide 18: Backup and Recovery
**Keep Your Data Safe**

**Create backup:**
```bash
make backup
```

**Restore from backup:**
```bash
make restore FILE=backup-file.tar.gz
```

**What gets backed up:**
- All user accounts
- User passwords
- User attributes
- Group memberships
- SSL certificates
- Configuration settings

**Always backup before making changes!**

---

## Slide 19: Troubleshooting Common Problems
**When Things Go Wrong**

**Problem: Authentication fails**
```bash
# Check if user exists
make view-ldap | grep username

# Test login manually
docker exec openldap ldapwhoami -x -H ldap://localhost -D "uid=username,ou=users,dc=domain,dc=com" -w "password"
```

**Problem: Certificate issues**
```bash
# Check certificate status
make health

# Renew certificates
make force-renew-certs
```

**Problem: Connection refused**
```bash
# Check if containers are running
docker compose ps

# Check if ports are open
netstat -tlnp | grep -E ":(389|636)"
```

---

## Slide 20: Best Practices for Testing
**Tips for Software Testers**

**Test different scenarios:**
- Valid users with correct passwords
- Valid users with wrong passwords
- Non-existent users
- Users with different access levels
- Multiple users connecting at once
- Network interruptions during login

**Document your tests:**
- Keep list of test users and passwords
- Record which access points you tested
- Note any problems or solutions
- Track performance results

**Regular maintenance:**
- Check logs weekly
- Backup data monthly
- Update certificates when needed
- Monitor system resources

---

## Slide 21: Summary
**What You've Learned**

✅ Set up complete LDAP server
✅ Created test users for WiFi authentication
✅ Made it work with enterprise access points
✅ Learned to monitor and troubleshoot
✅ Added custom users and attributes
✅ Tested authentication thoroughly

**You now have:**
- Production-ready LDAP server
- Automated SSL certificates
- Comprehensive testing tools
- Easy user management
- Complete monitoring system

---

## Slide 22: Next Steps
**What to Do Next**

**Immediate actions:**
1. Configure your access points
2. Test WiFi authentication
3. Add more users if needed
4. Set up monitoring alerts

**Future improvements:**
- Add more test scenarios
- Create automated test scripts
- Set up backup schedules
- Document your procedures

**Resources:**
- GitHub: github.com/dogkeeper886/ldap
- README.md for detailed documentation
- Makefile has 40+ useful commands

---

## Slide 23: Thank You!
**Questions and Support**

**Need help?**
- Check the README.md file
- Look at the troubleshooting section
- Review the logs for error messages
- Test with simple scenarios first

**Contact:**
- GitHub issues for bugs
- Documentation for questions
- Community forums for help

**Remember:**
- Always backup before changes
- Test in small steps
- Keep logs for troubleshooting
- Document your procedures

**Happy Testing!**
