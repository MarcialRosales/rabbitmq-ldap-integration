# Authentication and Tags

We expand on the previous scenario, [Only Authentication](../only-authentication/Readme.md), but this time we are going to configure which users gets which *user tags*.

To get the `administrator` *user tag*, users must belong to this LDAP group:

```
cn=administrator,ou=groups,dc=example,dc=com
```

To get the `monitoring` *user tag*, users must belong to this LDAP group:

```
cn=monitoring,ou=groups,dc=example,dc=com
```

We are going to grant `bob` the `administrator` *user tag* and we are going to create a new user called `prometheus` with the `monitoring` *user tag*. No other users have any *user tags* therefore they wont be able to access the management plugin (console and/or api).

## 1. Launch OpenLDAP

From within `authentication-and-tags` folder, run `start.sh` script to launch **OpenLDAP**. It will kill the container we ran on the previous scenario and it will start a new one. This is so that we start with a clean LDAP database.

## 2. Set up LDAP entries

1. We are going to expand the LDAP structure we used in the [previous scenario](../only-authentication/README.md), i.e. with 3 users (`bill`, `bob` and `joe`) and one organization called `ou=People,dc=example,dc=com`.
2. We are adding a new user `cn=prometheus,ou=People,dc=example,dc=com`.
3. We are adding one more organization called `ou=groups,dc=example,dc=com` with 2 LDAP groups underneath it, the `administrator` and `monitoring` groups.  (i.e. `cn=administrator,ou=groups,dc=example,dc=com` and `cn=monitoring,ou=groups,dc=example,dc=com`).
4. And finally, we are making `bob` a member of the `administrator` group and `prometheus` a member of the `monitoring` group.

```
          dc=example, dc=com
                  |
          +-------+---------+----------------------------------------+
          |                 |                                        |
   cn=admin,            ou=People,                                ou=groups
    dc=example,          dc=example,                               dc=example,
    dc=com               dc=com                                    dc=com
                            |                                        |
  +---------------+-----------+------------+                 +---------+------------+
  |               |           |            |                 |                      |
cn=prometheus  cn=bill      cn=bob        cn=joe            cn=administrator        cn=monitoring,
 ou=People      ou=People,   ou=People,    ou=People,        ou=groups,              ou=groups,
 dc=example,    dc=example,  dc=example,   dc=example,       dc=example,             dc=example,
 dc=com         dc=com       dc=com        dc=com            dc=com                  dc=com
                                                               |                       |
                                                               |                  ------------------
                                                               |                 cn=prometheus,ou=People,dc=example,dc=com  
                                                        ----------------       
                                                  cn=bob,ou=People,dc=example,dc=com       

```

Run the following command to create this structure:

```
./authentication-and-tags/import.sh
```

### 3. Configure RabbitMQ to authenticate users with our LDAP server and grant administrator and monitoring user tags

Edit your **rabbimq.config**, add the following configuration and restart RabbitMQ:

```
[
    {rabbit, [
        {auth_backends, [rabbit_auth_backend_ldap]}
    ]},
    {rabbitmq_auth_backend_ldap, [
        {servers,               ["localhost"]},
        {user_dn_pattern,       "cn=${username},ou=People,dc=example,dc=com"},
        {other_bind,            {"cn=admin,dc=example,dc=com", "admin"}},
        {tag_queries, [
            {administrator,     {in_group, "cn=administrator,ou=groups,dc=example,dc=com", "uniqueMember"}},
            {monitoring,        {in_group, "cn=monitoring,ou=groups,dc=example,dc=com", "uniqueMember"}}
        ]},
        {log, network_unsafe}
      ]}
].
```

This same configuration is available in the [rabbitmq.config](rabbitmq.config) should you want to copy files.

**Configuration explained**:

- What is RabbitMQ doing to check whether `bob` has the `administrator` *user tag*? It is running something like this:

```
ldapsearch -x -b "cn=administrator,ou=groups,dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w admin -LLL "(uniqueMember=cn=bob,ou=People,dc=example,dc=com)"
```

- Why do we need to configure `{other_bind, {"cn=admin,dc=example,dc=com", "admin"}},`? **Bind** is the authentication/login request in LDAP. Before we run any query, we must first bind with a given set of credentials. In our LDAP server, the user `cn=admin,dc=example,dc=com` can see every LDAP entry but the users we just created, e.g. `bob`, `joe` and `bill`, cannot see anything else except their own entry. By default, RabbitMQ uses the currently logged in user to run  *Authorization Queries* against LDAP. In other words, if we logged in as `bill`, RabbitMQ will bind this same user to run *Authorization Queries* such as *tag_queries*. However, those queries will not work because our user `bill` can barely see any LDAP entry so they won't see `ou=groups,dc=example,dc=com` or any entry underneath it. Should we encounter this situation, we can configure RabbitMQ to use a different user to bind with when running *Authorization Queries*.

- How do we grant `bob` the `administrator` *user tag*? We just need to place an `in_group` query that checks whether `bob` -the currently logged in user- is a member of the `cn=administrator,ou=groups,dc=example,dc=com` group.

- In the RabbitMQ docs, the attribute `member` is used instead of `uniqueMember`, why is that? This is because this installation of OpenLDAP did not support `GroupOfNames` objectType but `GroupOfUniqueNames` and this type of object has an attribute called `uniqueMember` rather than `member`.

**Recommendation**:
It would be highly recommended to create a user for rabbitmq in LDAP which has permission to
 - *search* starting from the root/base DN used by RabbitMQ to search for users and/or groups
 - *read* the attributes referenced by RabbitMQ searches such as `uniqueMember`.

The configuration used in this scenario is very simplistic and it uses the root user `cn=admin,dc=example,dc=com` which has *write* access to the entire LDAP tree.

**Work In Progress**:
Trying to set up the OpenLDAP server with a new user `cn=rabbitmq,dc=example,dc=com` which would have access to search and read from the rootDN so that we could use it in RabbitMQ Configuration as follows:
```
  ...
    {other_bind,            {"cn=rabbitmq,dc=example,dc=com", "somepassword"}},
    ...
```
