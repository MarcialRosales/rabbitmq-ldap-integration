# Hierarchical user organization

The scenarios we have seen so far such as [Only-Authentication](../only-authentication/README.md) or
[Authentication and Authorization](../auth-and-authz/README.md) forces us to have a **flat** user organization
in LDAP.

Let's take a look at the RabbitMQ configuration of the scenario called [Only-Authentication](../only-authentication/README.md):
```
[
    {rabbit, [
        {auth_backends, [rabbit_auth_backend_ldap]}
    ]},
    {rabbitmq_auth_backend_ldap, [
        {servers,          ["localhost"]},
        {user_dn_pattern,  "cn=${username},ou=People,dc=example,dc=com"},
        {tag_queries, [
            {administrator, {constant, false}},
            {management,    {constant, true }}
        ]},
        {log, network_unsafe}
    ]}
].
```

RabbitMQ looks up users using the query defined in `user_dn_pattern` which must contain exactly one instance of `${username}`. This imposes a flat user organization in LDAP. In our sample configuration, all users must be under `ou=People,dc=example,dc=com` LDAP branch as illustrated below:
```
          dc=example, dc=com
                  |
          +-------+---------+
                            |
                       ou=People,
                        dc=example,
                        dc=com
                            |
                +-----------+------------+
                |           |            |
            cn=bob       cn=bill       cn=joe
             ou=People,   ou=People,    ou=People,
             dc=example,  dc=example,   dc=example,
             dc=com       dc=com        dc=com
```

## Supporting hierarchical user organization in LDAP

Let's say users are organized in LDAP in a more hierarchical fashion like shown in the diagram below:
```
          dc=example, dc=com
                  |
          +-------+------------+----------------+
          |                    |                |
      ou=depart1          ou=depart2,        ou=depart3,
       dc=example,         dc=example,        dc=example,
       dc=com              dc=com             dc=com
          |                    |                |
    +-----------+              +                +
    |           |              |                |
  cn=bob       cn=bill       cn=joe           cn=alex
   ou=depart1,  ou=depart1,   ou=depart2,      ou=depart3,
   dc=example,  dc=example,   dc=example,      dc=example,
   dc=com       dc=com        dc=com           dc=com
```

Users like `bob` or `joe` are no longer under the common parent LDAP entry like `ou=People,dc=example,dc=com` but under their respective departments: `bob` under `ou=depart1,dc=example,dc=com` and `joe` under `ou=depart2,dc=example,dc=com`.

With this LDAP organization, we cannot look up users based on a DN pattern like `"cn=${username},ou=People,dc=example,dc=com"` because they do not share the same parent branch. Instead, we have to use a different lookup mechanism.

This new lookup mechanism has the following two prerequisites:
1. All users in LDAP must have the same LDAP attribute. In our scenario, we are going to use the `mail` attribute because all our users have the *ObjectClass* `inetOrgPerson` which defines the `mail` attribute. Later on we will see how we configure RabbitMQ to use this `mail` attribute
2. All users must have a *common base DN*. This is the *base DN* that RabbitMQ will use to search for the user's LDAP entry. In our example, the base DN is `dc=example,dc=com`.

Putting all the pieces together,
1. `bob@example.com` attempts to login to RabbitMQ with password `password`
2. RabbitMQ searches for an LDAP entry with `mail` attribute equal to the username, `bob@example.com`, starting the search from `dc=example,dc=com` and retrieve its DN.
  > We will see later on that in order to do the search operation RabbitMQ binds to **OpenLDAP** with a different user, not with `bob@example.com`
3. RabbitMQ gets back `cn=bob,ou=depart1,dc=example,dc=com` from LDAP
4. RabbitMQ binds with that DN, `cn=bob,ou=depart1,dc=example,dc=com`, and password `password`
5. **OpenLDAP** accepts the bind operation and the user is successfully logged in by RabbitMQ

Once the requirements are clear, let's implement the scenario.


## 1. Launch OpenLDAP

Run `start.sh` script to launch **OpenLDAP**. It will kill the container we ran on the previous scenario and it will start a new one. This is so that we start with a clean LDAP database.

## 2. Set up LDAP entries

Run the following command to create the LDAP structure shown in the diagram:

```
./import.sh
```

It creates 4 users under their respective departments. The users' password is `password`.

### 3. Configure RabbitMQ

Edit your `rabbimq.config`, add the following configuration and restart RabbitMQ:
```
[
    {rabbit, [
        {auth_backends, [rabbit_auth_backend_ldap]}
    ]},
    {rabbitmq_auth_backend_ldap, [
        {servers,             ["localhost"]},
        {dn_lookup_attribute, "mail"},
        {dn_lookup_base,      "dc=example,dc=com"},
        {dn_lookup_bind,      {"cn=admin,dc=example,dc=com", "admin"}},
        {tag_queries, [
            {administrator,   {constant, false}},
            {management,      {constant, true }}
        ]},
        {log, network_unsafe}
    ]}
].
```

> For your convenience, there is a [rabbitmq.config](rabbitmq.config) file with this configuration.

**Configuration explained**:
- `dn_lookup_attribute` contains the attribute RabbitMQ uses to search for users' LDAP entries. In our case, we use `mail`
- RabbitMQ will start searching from the base DN configured in `dn_lookup_base`
- If we did not configured `dn_lookup_bind` with the value `{"cn=admin,dc=example,dc=com", "admin"}}` RabbitMQ would have taken the default value which is `as_user`. This means RabbitMQ would try to bind using the user's email address. However, our **OpenLDAP** server only accepts bind operations with **Distinguish Names** not with plain values like an email address.
- We have to configure `dn_lookup_bind` with the DN and password of a user that exists in LDAP. In our case, it is `{"cn=admin,dc=example,dc=com", "admin"}}`.


### 4. Verify Configuration

1. Make sure that `bob` can access the Management API using its email address `bob@example.com`
  ```
  curl -u bob@example.com:password http://localhost:15672/api/overview | jq .
  ```
2. Make sure that `bob` cannot log in as `bob`
  ```
  curl -u bob:password http://localhost:15672/api/overview | jq .
  ```
  It should produce this response:
  ```
  {
  "error": "not_authorised",
  "reason": "Login failed"
  }
  ```
3. Make sure that `bob` can access RabbitMQ via AMQP using `bob@example.com`
  ```
  ruby bob.rb
  ```
  It should produce this response:
  ```
  Connected !!
  Press any key to terminate
  ```
