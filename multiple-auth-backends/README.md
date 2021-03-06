# Use multiple Authentication backends

In the previous scenarios, we only used LDAP to authenticate users and authorize their requests.

In this scenario, we are tasked to support the internal authentication backend in addition to LDAP. This is a common scenario found when we use [RabbitMQ for PCF](https://docs.pivotal.io/rabbitmq-cf/1-12/index.html). **RabbitMQ for PCF** creates an administrator user in RabbitMQ internal databases and it uses this user to create **vhosts**, **users** and assign permissions to those **users**. If we only configured **RabbitMQ for PCF** with just LDAP authentication backend, it would not be able to properly work anymore as it would not be able to perform the actions mentioned above.

Let's say we have this LDAP structure below. We have one organization unit for all the applications with DN `ou=apps,dc=example,dc=com`, and 3 applications under it. All 3 applications have `password` as their password.

```
        dc=example, dc=com
                |
        +-------+---------+
                          |
                     ou=apps,
                      dc=example,
                      dc=com
                          |
              +-----------+------------+
              |           |            |
          cn=app100     cn=app101     cn=app102
           ou=apps,       ou=apps,      ou=apps,
           dc=example,    dc=example,   dc=example,
           dc=com         dc=com        dc=com          
```

We configure RabbitMQ to first authenticate  with LDAP and fallback to the internal database.
```
[
    {rabbit, [
        {auth_backends, [rabbit_auth_backend_ldap, rabbit_auth_backend_internal]}
    ]},
    {rabbitmq_auth_backend_ldap, [
        {servers,               ["localhost"]},
        {user_dn_pattern,       "cn=${username},ou=apps,dc=example,dc=com"},
        {tag_queries, [
            {administrator,     {constant, false}},
            {management,        {constant, true}}            
        ]},
        {log, network}
    ]}
].
```

**Scenario 1 - `app100` user only exists in LDAP**

1. `app100` tries to login with RabbitMQ
2. RabbitMQ authenticates it with **LDAP**
3. **LDAP** accepts it because there is an LDAP entry with DN = `cn=app100,ou=apps,dc=example,dc=com` and has the password `password`
4. RabbitMQ checks with **LDAP** if the user has `administrator` *user tag*
5. **LDAP** replies with `false`

**Scenario 2 - `app100` user exists in LDAP and internal**

`app100` exists in LDAP and internal with the same password. It has `administrator` *user tag* in the internal backend and `management` *user tag* in LDAP.

1. `app100` tries to login with RabbitMQ
2. RabbitMQ authenticates it with **LDAP**
3. **LDAP** accepts it because there is an LDAP entry with DN = `cn=app100,ou=apps,dc=example,dc=com` and has the password `password`
4. RabbitMQ checks with **LDAP** if the user has `administrator` *user tag*
5. **LDAP** replies with `false`
6. RabbitMQ does not check with the **internal** backend. It stops here.

**TL;DR** RabbitMQ would only fallback to the internal when it cannot find the user in LDAP. But if the user is in LDAP, all the authorization request are done with LDAP.

**Scenario 3 - `guest` user only exists in internal**

`guest` user exists in the internal database and it has the `administrator` *user tag*. However, all users in LDAP are not configured with `administrator` *user tag*.

1. `guest` tries to login with RabbitMQ
2. RabbitMQ tries to authenticate it with **LDAP**
3. **LDAP** does not recognize it
4. RabbitMQ successfully authenticates it with **internal** backend
5. RabbitMQ checks with **internal** backend that the user has `administrator` *user tag*
  > RabbitMQ does not check with **LDAP**, it sticks to **internal**

6. User gets granted `administrator` *user tag*

**TL;DR** In order to fully centralize access control in LDAP, we need to make sure that all users defined in RabbitMQ internal database are also defined in LDAP. Should we failed to do it, authentication and authorization would be performed outside of LDAP radar.


# Exploring all possible configurations with auth_backends

We are going to run all possible scenarios to fully understand how exactly we can configure `auth_backends` to support multiple AuthN and AuthZ backends.


### Scenario 1 - LDAP first, fallback internal
`rabbitmq.config` is:
```
{auth_backends, [rabbit_auth_backend_ldap, rabbit_auth_backend_internal]}
```

We can read this configuration as follows: [`auth_backend_1`, `auth_backend_2`] where an `auth_backend` is responsible of both **authentication**, a.k.a. **AuthN** and **authorization**, a.k.a. **AuthZ**.

We saw in the previous section the outcome of this configuration.
- Users are first authenticated with **LDAP**
- Users are authenticated with **internal** if **LDAP** fails to bind the user. It could be that the user does not exist or that its password does not match. It could be either case.
- If the user is authenticated with **LDAP**, RabbitMQ uses **LDAP** to resolve all the authorization requests (i.e. *vhosts*, *user tags*, etc). It is important to understand that there is no fallback concept for authorization requests. Should LDAP returned `false` to an authorization request like `tag_query.administrator`, RabbitMQ will not check with the next backend.
- If the user is authenticated with **internal**, RabbitMQ uses **internal** to resolve all the authorization requests. It will not check first with **LDAP**.

### Scenario 2 - AuthN with LDAP, AuthZ with internal
`rabbitmq.config` is:
```
{auth_backends, [{rabbit_auth_backend_ldap, rabbit_auth_backend_internal}]}
```

We can read this configuration as follows: [ {`authN_backend_1`, `authZ_backend_1`} ]. There is just one authN backend and one authZ backend, but they are different.

- Users are ONLY authenticated with **LDAP**
- Users are ONLY authorized with **internal**

### Scenario 3 - AuthN with LDAP first, AuthZ with internal. Fallback LDAP AuthN to internal, AuthZ with internal.
```
{auth_backends, [
    {rabbit_auth_backend_ldap, rabbit_auth_backend_internal},
    {rabbit_auth_backend_internal}]}
```

We can read this configuration as follows: [ {`authN_backend_1`, `authZ_backend_1`}, { `auth_backend_2`} ]. `auth_backend_2` is the fallback to `authN_backend_1`.

- Users are first authenticated with **LDAP** (`authN_backend_1`)
- If **LDAP** accepts it, Users are then authorized with **internal** (`authZ_backend_1`).
- If **LDAP** does not accept it, Users are then authenticated with **internal** (`auth_backend_2`). Authorization is also performed by **internal** too (`auth_backend_2`).
- This configuration implies that all users must be defined in **internal** because authorization is always done by **internal**. However, we don't need to have all users' passwords in **internal**, they can be defined in **LDAP** if required. In the contrary, the password has to be also defined in **internal**.
