# Speaking Script: LDAP WiFi Authentication Server Setup
## For Software Testers

---

## Introduction (0:00 - 0:30)

**Hello everyone!** Welcome to this tutorial. I'm going to show you how to set up an LDAP server for testing WiFi authentication. 

**What is LDAP?** Think of it like a phone book for computers. It stores user names and passwords. When someone tries to connect to WiFi, the access point asks the LDAP server "Is this person allowed to connect?" The LDAP server checks and says yes or no.

**Why do we need this?** As software testers, we need to test if WiFi authentication works properly. We need to make sure users can connect, wrong passwords are rejected, and security works as expected.

**Today I'll show you:** How to set up a complete LDAP server in just a few minutes, create test users, and test WiFi authentication. This will work with enterprise access points like RUCKUS, Cisco, and Aruba.

---

## What We'll Build (0:30 - 1:00)

**Let me show you what we're building today:**

We'll create a complete LDAP server that has:
- **Security built-in** - Everything is encrypted with SSL certificates
- **Automatic certificates** - The system gets and renews certificates automatically
- **Five test users** - Ready to use with different access levels
- **Enterprise compatibility** - Works with Microsoft Active Directory style access points
- **Easy monitoring** - Tools to check if everything is working
- **Simple management** - Easy to add users and change settings

**This isn't just a demo** - this is a real, production-ready system that you can use for actual WiFi testing.

---

## What You Need (1:00 - 1:30)

**Before we start, let me tell you what you need:**

**For your computer:**
- A Linux server - this could be Ubuntu, CentOS, or similar
- Docker installed - this runs our LDAP server in a container
- Docker Compose installed - this manages multiple containers
- Basic command line knowledge - you need to type some commands

**For your network:**
- A domain name that points to your server
- Ports 389, 636, and 80 need to be open
- Internet connection

**Time needed:**
- Setup takes about 10-15 minutes
- Testing takes another 5-10 minutes

**Don't worry if you're not sure about some of these** - I'll show you how to check and fix common problems.

---

## Step 1: Download and Setup (1:30 - 2:30)

**Let's start by getting the project files.**

First, I'll download the project from GitHub. This contains all the code and configuration files we need.

```bash
git clone https://github.com/dogkeeper886/ldap.git
cd ldap
```

**Now I need to create a configuration file.** This file tells the system what domain to use, what password to set, and other important settings.

```bash
cp .env.example .env
```

**Let me edit this file** to put in my settings. I'll open it with a text editor:

```bash
nano .env
```

**Here's what I need to change:**
- LDAP_DOMAIN - this is my domain name, like "mytest.com"
- LDAP_ADMIN_PASSWORD - this is the password for the admin user
- LETSENCRYPT_EMAIL - this is my email for SSL certificates

**I'll save this file** and we're ready for the next step.

---

## Step 2: One Command Setup (2:30 - 4:00)

**Now comes the magic part - one command does everything!**

```bash
make init
```

**Let me explain what this command does:**

First, it builds the Docker containers. Think of containers like boxes that contain everything needed to run our LDAP server.

Then, it gets SSL certificates automatically. These certificates make the connection secure - like having a lock on your door.

Next, it starts the LDAP server with security enabled.

Finally, it sets up the directory structure - this is like creating folders to organize our users.

**This process takes about 2-3 minutes** depending on your internet connection. You'll see lots of text scrolling by - that's normal, it's just the system working.

**When it's done, you'll see a success message** saying the initial setup is complete.

---

## Step 3: Create Test Users (4:00 - 5:00)

**Now let's create some test users.** These are the accounts we'll use to test WiFi authentication.

```bash
make setup-users
```

**This creates five different users:**

- **test-user-01** - This is John Smith, an IT Administrator. Password is "TestPass123!"
- **test-user-02** - This is Jane Doe, a Network Engineer. Password is "TestPass456!"
- **test-user-03** - This is Mike Johnson, a Guest User. Password is "GuestPass789!"
- **test-user-04** - This is a Contractor. Password is "ContractorPass321!"
- **test-user-05** - This is a VIP User. Password is "VipPass654!"

**Each user has complete information:**
- Full name
- Email address
- Phone number
- Department they work in
- Access level they have

**This gives us different types of users** to test different scenarios - like what happens when a guest tries to connect versus an administrator.

---

## Step 4: Add Enterprise Compatibility (5:00 - 6:00)

**Many enterprise access points expect Microsoft Active Directory attributes.** Let me add those so our LDAP server works with more equipment.

```bash
make add-msad-attributes
```

**This adds important attributes:**

- **sAMAccountName** - This is like a Windows-style username
- **userPrincipalName** - This is like "user@domain.com" format
- **userAccountControl** - This tells if an account is enabled or disabled
- **memberOf** - This shows which groups a user belongs to

**Why does this matter?** Many enterprise access points are configured to work with Microsoft Active Directory. By adding these attributes, our LDAP server can pretend to be like Microsoft AD, so more equipment will work with it.

**You'll see the system adding these attributes** to all our test users. When it's done, our server will be compatible with enterprise access points.

---

## Step 5: Check Everything Works (6:00 - 7:00)

**Now let's make sure everything is working properly.** I'll run a health check.

```bash
make health
```

**This checks 12 different things:**

- Are Docker services running? ✓
- Are the containers healthy? ✓
- Does the LDAP connection work? ✓
- Are the SSL certificates valid? ✓
- Do our test users exist? ✓
- Does authentication work? ✓
- Are all the required attributes present? ✓
- Are system resources OK? ✓

**You'll see a report** with green checkmarks for things that work and red X's for problems. If everything is green, your server is ready to use!

**If you see any red X's**, don't worry - I'll show you how to fix common problems later in the video.

---

## Step 6: Test Authentication (7:00 - 8:00)

**Let's run some tests to make sure users can actually log in.**

```bash
make test-auth
```

**This runs 10 different tests:**

- **Valid user login** - Does a real user with the right password work? ✓
- **Wrong password rejection** - Does a real user with wrong password get rejected? ✓
- **Non-existent user rejection** - Does a fake user get rejected? ✓
- **Empty password rejection** - Does an empty password get rejected? ✓
- **SSL connection** - Does the secure connection work? ✓
- **Admin login** - Can the admin user log in? ✓
- **Multiple users** - Can several users connect at the same time? ✓
- **Performance** - Is it fast enough? ✓

**All tests should pass.** If they do, your LDAP server is working perfectly and ready for WiFi testing!

---

## Configure Your WiFi Access Point (8:00 - 9:00)

**Now let's configure a WiFi access point to use our LDAP server.**

**For RUCKUS One access points, here are the settings:**

- **Server Type:** LDAP/LDAPS
- **Server:** your-domain.com (use your actual domain)
- **Port:** 636 for secure connection, or 389 for non-secure
- **Base DN:** dc=your,dc=domain,dc=com (replace with your domain)
- **Admin DN:** cn=admin,dc=your,dc=domain,dc=com
- **Admin Password:** [the password you set in the .env file]
- **Search Filter:** uid=%s

**For access points that expect Microsoft Active Directory, use these search filters instead:**

- **Standard:** uid=%s
- **MS AD Style:** (sAMAccountName=%s)
- **UPN Style:** (userPrincipalName=%s@your-domain.com)
- **Combined:** (|(sAMAccountName=%s)(userPrincipalName=%s@your-domain.com))

**The %s gets replaced with the username** that the person types when they try to connect to WiFi.

---

## Test WiFi Authentication (9:00 - 10:00)

**Now let's test if WiFi authentication actually works.**

**On your device:**

1. **Connect to the WiFi network** that's configured to use our LDAP server
2. **Choose WPA2/WPA3 Enterprise** as the security type
3. **Choose EAP method** - usually PEAP or EAP-TTLS
4. **Enter username:** test-user-01
5. **Enter password:** TestPass123!
6. **Accept the certificate** if your device asks

**If everything is configured correctly, you should connect successfully!**

**Try with different users:**
- test-user-02 with password TestPass456!
- test-user-03 with password GuestPass789!

**Try with wrong password** - it should reject you.

**This proves that your LDAP server is working** and can authenticate WiFi users properly.

---

## Adding New Users (10:00 - 11:30)

**Sometimes you need to add more test users.** Let me show you how.

**Method 1: Use a script**

I'll create a simple script that adds a new user:

```bash
nano add-user.sh
```

**In this script, I'll put:**
- The username I want to create
- The full name
- Email address
- Phone number
- Department
- Password

**Then I'll make it executable and run it:**
```bash
chmod +x add-user.sh
./add-user.sh
```

**Method 2: Manual command**

If you want to add a user directly, you can use this command:

```bash
echo "dn: uid=newuser,ou=users,dc=domain,dc=com
objectClass: inetOrgPerson
uid: newuser
cn: New User
mail: newuser@domain.com" | docker exec -i openldap ldapadd -x -H ldap://localhost -D "cn=admin,dc=domain,dc=com" -w "admin-password"
```

**This creates a new user** with the basic information. You can then set a password and add more attributes as needed.

---

## Adding Custom Attributes (11:30 - 12:30)

**Sometimes you need to add special properties to users.** For example, you might want to add a security clearance level.

**Here's how to add a custom attribute:**

```bash
echo "dn: uid=test-user-01,ou=users,dc=domain,dc=com
changetype: modify
add: description
description: High security clearance" | docker exec -i openldap ldapmodify -x -H ldap://localhost -D "cn=admin,dc=domain,dc=com" -w "admin-password"
```

**This adds a description** to test-user-01 saying they have high security clearance.

**Other useful attributes you might add:**
- **employeeType:** Full-Time, Contractor, Intern
- **location:** Building-A, Building-B, Remote
- **clearanceLevel:** Public, Internal, Confidential
- **accessGroup:** WiFi-Standard, WiFi-Guest, WiFi-Admin

**These attributes can be used** by your access points to decide what level of access to give each user.

---

## Viewing and Managing Users (12:30 - 13:30)

**Let me show you how to see what users you have and manage them.**

**To see all users:**
```bash
make view-ldap
```

**This shows you a list** of all users, their attributes, and group memberships.

**To search for a specific user:**
```bash
docker exec openldap ldapsearch -x -H ldap://localhost -D "cn=admin,dc=domain,dc=com" -w "admin-password" -b "dc=domain,dc=com" "uid=test-user-01"
```

**This shows you detailed information** about just that one user.

**To change a user's password:**
```bash
docker exec openldap ldappasswd -x -H ldap://localhost -D "cn=admin,dc=domain,dc=com" -w "admin-password" -s "NewPassword123!" "uid=test-user-01,ou=users,dc=domain,dc=com"
```

**This changes the password** for test-user-01 to "NewPassword123!".

**These commands help you manage your users** and troubleshoot authentication problems.

---

## Monitoring and Logs (13:30 - 14:30)

**It's important to monitor your LDAP server** to see what's happening and catch problems early.

**To view all logs:**
```bash
make logs
```

**This shows you recent log entries** from all services.

**To follow logs in real-time:**
```bash
make logs-follow
```

**This shows you new log entries** as they happen. Press Ctrl+C to stop.

**To view only LDAP logs:**
```bash
make logs-ldap
```

**This shows you only** the LDAP server logs, which are usually the most important.

**To check for errors:**
```bash
docker logs openldap --tail=50 | grep -i "error"
```

**This shows you any error messages** in the recent logs.

**What to look for in logs:**
- **Authentication attempts** - who's trying to log in
- **Connection errors** - problems connecting to the server
- **Certificate renewals** - when SSL certificates are updated
- **Performance issues** - if the server is running slowly

**Regular log checking helps you** catch problems before they become serious.

---

## Advanced Testing (14:30 - 15:30)

**Let me show you some more advanced testing scenarios** that software testers commonly need.

**Performance testing:**
```bash
make test-performance
```

**This tests how fast** the server can handle authentication requests.

**TLS/SSL testing:**
```bash
make test-tls
```

**This tests if the secure connections** are working properly.

**Attribute testing:**
```bash
make test-attributes
```

**This tests if all the required attributes** for enterprise access points are present.

**Load testing - many users at once:**
```bash
for i in {1..10}; do
  docker exec openldap ldapsearch -x -H ldap://localhost -D "uid=test-user-01,ou=users,dc=domain,dc=com" -w "TestPass123!" -b "" -s base &
done
```

**This simulates 10 users** trying to authenticate at the same time.

**These tests help you verify** that your server can handle real-world usage.

---

## Backup and Recovery (15:30 - 16:30)

**Always backup your LDAP data** before making changes. You never know when something might go wrong.

**To create a backup:**
```bash
make backup
```

**This creates a backup file** with all your data, including:
- All user accounts
- User passwords
- User attributes
- Group memberships
- SSL certificates
- Configuration settings

**To restore from a backup:**
```bash
make restore FILE=backup-file.tar.gz
```

**This restores everything** from the backup file.

**I recommend backing up:**
- Before making any changes
- After adding new users
- Before updating the system
- On a regular schedule

**Backups save you time** if something goes wrong and you need to start over.

---

## Troubleshooting Common Problems (16:30 - 17:30)

**Let me show you how to fix common problems** that you might encounter.

**Problem: Authentication fails**

First, check if the user exists:
```bash
make view-ldap | grep username
```

Then test the login manually:
```bash
docker exec openldap ldapwhoami -x -H ldap://localhost -D "uid=username,ou=users,dc=domain,dc=com" -w "password"
```

**Problem: Certificate issues**

Check certificate status:
```bash
make health
```

If certificates are expired, renew them:
```bash
make force-renew-certs
```

**Problem: Connection refused**

Check if containers are running:
```bash
docker compose ps
```

Check if ports are open:
```bash
netstat -tlnp | grep -E ":(389|636)"
```

**Most problems are easy to fix** once you know what to look for.

---

## Best Practices for Testing (17:30 - 18:00)

**Here are some tips for software testers** using this LDAP server.

**Test different scenarios:**
- Valid users with correct passwords
- Valid users with wrong passwords
- Non-existent users
- Users with different access levels
- Multiple users connecting at once
- Network interruptions during login

**Document your tests:**
- Keep a list of test users and passwords
- Record which access points you tested
- Note any problems or solutions
- Track performance results

**Regular maintenance:**
- Check logs weekly
- Backup data monthly
- Update certificates when needed
- Monitor system resources

**Following these practices** helps you catch problems early and keep your testing environment reliable.

---

## Summary and Next Steps (18:00 - 18:30)

**Congratulations! You now have a complete LDAP server** for WiFi authentication testing.

**What you've accomplished:**
- Set up a production-ready LDAP server
- Created test users for WiFi authentication
- Made it work with enterprise access points
- Learned to monitor and troubleshoot
- Added custom users and attributes
- Tested authentication thoroughly

**Your next steps:**
1. Configure your access points with the LDAP settings
2. Test WiFi authentication with different users
3. Add more users if needed
4. Set up monitoring alerts
5. Document your testing procedures

**Resources for help:**
- GitHub repository: github.com/dogkeeper886/ldap
- README.md file for detailed documentation
- Makefile has 40+ useful commands

**Remember:** Always backup before making changes, test in small steps, and keep logs for troubleshooting.

**Thank you for watching!** If this video helped you, please like and subscribe for more testing tutorials. Leave a comment if you have questions or want to see specific testing scenarios covered in future videos.

**Happy testing!**

