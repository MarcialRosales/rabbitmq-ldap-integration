# Only Authentication

In this scenario we will configure RabbitMQ so that users are authenticated against the LDAP database and not against the internal RabbitMQ Database. So, even if we had the default user `guest:guest`, we wont be able to authenticate it with it anymore. We can certainly configure RabbitMQ to use both, first LDAP and then the internal, but this is not the option we will configure at this time.

In this scenario, we are not going to configure authorization, i.e. users will be allowed to access any resource on any vhost.

No users will have the `administrator` tag but all users will have the `management` tag. This is the role required to access the management plugin (console and/or api).

## 1. Set up OpenLDAP

Run `start.sh` script to launch **OpenLDAP**. It will run with just one root DN and one user. See details below:
  - Root DN: `dc=example,dc=com`
  - Default user's distinguish name `cn=admin,dc=example,dc=com` and password `admin`.

Copy `../.ldaprc` to your home directory. This file provides default values to the *LDAP* commands we will run later on otherwise we would need to pass the credentials to our LDAP server on every command.

To verify **OpenLDAP** is running, run the following command:

```
ldapsearch -x -LLL -s base -b "" namingContexts
```

If it works, it should return

```
dn:
namingContexts: dc=example,dc=com
```

> Note with regard start.sh: We can run it as many times as want. If it was already running, it will kill it and start new one. This is so that we start with a clean LDAP database. You will need to import the schema again though.

## 2. Brief Introduction to LDAP

For those who are new to LDAP, think of LDAP as a file system. On a file system, we create files and typically we create them under directories/subfolders. Similarly, in LDAP we create *objects* rather than files and those *objects* are created within a naming scheme similar to directories. In a file system, we can refer to a file by using its name (e.g. `Readme.md`) or by using its absolute path (`/home/bob/Readme.md`). Similarly, in LDAP an *object* has a name specified by the attribute `cn` (Common Name) but more importantly it has a unique and fully qualified name `dn` (Distinguised Name). For instance, the single user defined in our LDAP installation has the name `cn=admin` and its fully qualified name is `cn=admin,dc=example,dc=com`.

In terms of tree structure this is what it is like:

```
      dc=example, dc=com               <== Root DN
          |
          |
   cn=admin, dc=example, dc=com     <== Our admin user
```

Let's run a command that returns all the entries under `dc=example, dc=com`:

```
ldapsearch -x -b "dc=example,dc=com" -w admin
```

It returns 2 objects, the **top** one and the `admin` user:

```
# example.com
dn: dc=example,dc=com
objectClass: top
objectClass: dcObject
objectClass: organization
o: Only authentication
dc: example

# admin, example.com
dn: cn=admin,dc=example,dc=com
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
description: LDAP administrator
userPassword:: e1NTSEF9MlYwbnZwZWVwZmJPazJjTHRUbUcwMXdDTE5nNDAwR2E=
```

There is a concept of `objectClass` in LDAP that defines a set of attributes for an object. An LDAP  `object` may have one or many `objectClass`(s). For instance, the `admin` user has 2 `objectClass`(s), one of them is `simpleSecurityObject` which has an attribute called `userPassword`.

If we wanted to return only the users which has the class `simpleSecurityObject` (Check out [Common LDAP schemas](https://oav.net/mirrors/LDAP-ObjectClasses.html) for other object classes and their attributes) we could run:

```
ldapsearch -x -b "dc=example,dc=com" -w admin "(objectClass=simpleSecurityObject)"
```

Note: We always have to specify the password `-w admin` however we dont specify the hostname or port because that is defined in the `~/.ldaprc` file.

Or if we wanted to search by its `cn` attribute:

```
ldapsearch -x -w admin "cn=admin
```

Note: We can also omit the base dn `-b  "dc=example,dc=com"` that is also in the  `~/.ldaprc` file.

## 3. Create users in LDAP

Once we have LDAP running, we need to import the users we want to authenticate with. Without LDAP integration in RabbitMQ, we had to manually create these users via the *Management Console* or via `rabbitmqctl add_user <username> <password>`.

This is the LDAP organization we are aiming for:

```
          dc=example, dc=com
                  |
          +-------+---------+
          |                 |
   cn=admin,            ou=People,
    dc=example,          dc=example,
    dc=com               dc=com
                            |
                +-----------+------------+
            cn=bob       cn=bill       cn=joe
             ou=People,   ou=People,    ou=People,
             dc=example,  dc=example,   dc=example,
             dc=com       dc=com        dc=com
```

Run the following command to create this structure:

```
./import.sh
```

`import.ldif` follows LDAP format to define the objects we want to create.

All users share the same password `password`. To obtain the SHA encoded version of it I ran: `slappasswd -h {SHA} -s password`

We should get the following output:

```
adding new entry "ou=People,dc=example,dc=com"

adding new entry "cn=bob,ou=People,dc=example,dc=com"

adding new entry "cn=bill,ou=People,dc=example,dc=com"

adding new entry "cn=joe,ou=People,dc=example,dc=com"
```

We can now search for all users under our organization `People` but only return their `dn` -distinguished name:

```
ldapsearch -x -w admin -b "ou=People,dc=example,dc=com" -s one dn
```

We should get back:

```
# bob, People, example.com
dn: cn=bob,ou=People,dc=example,dc=com

# joe, People, example.com
dn: cn=joe,ou=People,dc=example,dc=com

# bill, People, example.com
dn: cn=bill,ou=People,dc=example,dc=com
```

### 4. Configure RabbitMQ to authenticate users with our LDAP server

Edit the `/etc/rabbitmq/rabbitmq.config` file, add the following configuration and restart RabbitMQ:

```
[
    {rabbit, [
        {auth_backends, [rabbit_auth_backend_LDAP]}
    ]},
    {rabbitmq_auth_backend_ldap, [
        {servers,         [ "localhost"]},
        {user_dn_pattern, "cn=${username},ou=People,dc=example,dc=com"},
        {tag_queries, [
            {administrator, {constant, false}},
            {management,    {constant, true}}
        ]},
        {log, network}
    ]}
].
```

This same configuration is available in the file rabbitmq.config should you want to copy files.

**Configuration explained**:

- Users are only defined in LDAP. In other words, the internal RabbitMQ database is not used.
- No users have access as `administrator` to the management plugin
- All users have access as `management` to the management plugin
  To test the management access, run `curl -u john:password http://localhost:15672/api/overview | jq .` to validate it
- All users have access to any vhost
  To test **amqp** access, run `bin/runjava com.rabbitmq.perf.PerfTest --uri amqp://john:password@localhost:5672/%2F`
- Users must be declared in LDAP under the **organizational Unit** `ou=People,dc=example,dc=com`.
- Users will login onto RabbitMQ using a plain **username**. We need to map this plain name onto a distinguished name that corresponds to the same user.
  To configure this mapping we add the following entry to the configuration: `{user_dn_pattern, "cn=${username},ou=People,dc=example,dc=com"},`
- What is exactly RabbitMQ doing during the authentication process? It is doing a **bind** Request with `-D "cn=joe,ou=People,dc=example,dc=com"` and password `-w password"` (this is the password we pass to RabbitMQ either via the **http** or **amqp** protocols).  If the DN specified in `-D` argument matches with an LDAP entry of type `objectClass: simpleSecurityObject` and the `userPassword` attribute of that entry also matches with the password passed to Rabbit the authentication is accepted.
