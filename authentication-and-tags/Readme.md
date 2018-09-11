# Authentication and Tags

We expand on the previous scenario, [Only Authentication](../only-authentication/Readme.md), but this time we are going to configure which users gets which *user tags*.

To get the `administrator` *user tag*, users must belong to the LDAP group `cn=administrator,ou=groups,dc=example,dc=com`.
To get the `monitoring` *user tag*, users must belong to the LDAP group `cn=monitoring,ou=groups,dc=example,dc=com`.  

We are going to grant `bob` the `administrator` *user tag* and we are going to create a new user called `prometheus` with the `monitoring` *user tag*

## 1. Set up OpenLDPA

Run `start.sh` script to launch **OpenLdap**. It will kill the container we run on the previous scenario and it will start a new one. This is so that we start with a clean LDAP database.

## 2. Create users in LDAP

We are going to add start with the same LDAP structure we used in the [previous scenario](../only-authentication/Readme.md)
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
cn=prometheus  cn=bill      cn=bo         cn=joe            cn=administrator        cn=monitoring,
 ou=People      ou=People,   ou=People,    ou=People,        ou=groups,              ou=groups,
 dc=example,    dc=example,  dc=example,   dc=example,       dc=example,             dc=example,
 dc=com         dc=com       dc=com        dc=com            dc=com                  dc=com
```

Run the following command to create this structure:   
`ldapadd -x -w admin -f import.ldif`


### 3. Configure RabbitMq to authenticate users with our LDAP server and grant administrator and monitoring user tags

Edit your **rabbimq.config** and add the following configuration:
```
[
    { rabbit,
      [
        {auth_backends, [rabbit_auth_backend_ldap]}
      ]
    },
    { rabbitmq_auth_backend_ldap,
      [
        {servers,               ["localhost"] },
        {user_dn_pattern,       "cn=${username},ou=People,dc=example,dc=com"},

        {other_bind,            { "cn=admin,dc=example,dc=com", "admin"  } },
        {group_lookup_base,     "ou=groups,dc=example,dc=com"},
        {tag_queries, [
               {administrator,  { in_group, "cn=administrators,ou=groups,dc=example,dc=com" , "uniqueMember" }},
               {monitoring,     { in_group, "cn=monitoring,ou=groups,dc=example,dc=com" , "uniqueMember" }}
               ]
        },
        {log, network}

      ]
    }
].
```

**Configuration explained**:
- What is RabbitMQ doing to grant *user tags*? `ldapsearch -x -b "cn=administrators,ou=groups,dc=example,dc=com" -w admin -LLL "(uniqueMember=cn=bob,ou=People,dc=example,dc=com)"`
