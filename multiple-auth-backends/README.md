# Use multiple Authentication backends

In the previous scenarios, we only used LDAP to authenticate users and authorize their requests.

In this scenario, we are tasked to support the internal authentication backend in addition to LDAP. This is a common scenario found when we use [RabbitMQ for PCF](https://docs.pivotal.io/rabbitmq-cf/1-12/index.html). **RabbitMQ for PCF** creates an administrator user in RabbitMQ internal databases and it uses this user to create **vhosts**, **users** and assign permissions to those **users**. If we only configured **RabbitMQ for PCF** with just LDAP authentication backend, it would not be able to properly work anymore as it would not be able to perform the actions mentioned above.

## 1. Configure RabbitMQ to authenticate users with our LDAP server else with RabbitMQ internal database

Edit your **rabbimq.config**, add the following configuration and restart RabbitMQ:

```
[
    {rabbit, [
        {auth_backends, [rabbit_auth_backend_ldap, rabbit_auth_backend_internal]}
    ]},
    {rabbitmq_auth_backend_ldap, [
        {servers,               ["localhost"]},
        {user_dn_pattern,       "cn=${username},ou=People,dc=example,dc=com"},
        {other_bind,            {"cn=admin,dc=example,dc=com", "admin"}},
        {tag_queries, [
            {administrator,     {in_group, "cn=administrator,ou=groups,dc=example,dc=com", "uniqueMember"}},
            {monitoring,        {in_group, "cn=monitoring,ou=groups,dc=example,dc=com", "uniqueMember"}},
            {management,        {constant, true}},
            {policymaker,       {in_group, "cn=administrator,ou=${vhost},ou=env,dc=example,dc=com", "uniqueMember"}}
        ]},
        {vhost_access_query,    {in_group, "cn=users,ou=${vhost},ou=env,dc=example,dc=com", "uniqueMember"}},
        {resource_access_query,
            {'or', [
                {for, [
                    {permission, configure, {in_group, "cn=administrator,ou=${vhost},ou=env,dc=example,dc=com", "uniqueMember"}}
                ]},
                {for, [
                    {resource, exchange, {match,
                                             {string, "${name}"},
                                             {string, "^${username}-x"}
                    }},
                    {resource, queue,    {match,
                                             {string, "${name}"},
                                             {string, "^${username}-q"}
                    }}
                ]},
                {in_group, "cn=${name}-${permission},ou=${vhost},ou=env,dc=example,dc=com", "uniqueMember"}
            ]}
        },
        {log, network}
    ]}
].
```


## Exploring all possible configurations with auth_backends

We are going to run all possible scenarios to fully understand how exactly we can configure `auth_backends` to support multiple AuthN and AuthZ backends.


### Scenario 1
Given this setup
- `{auth_backends, [rabbit_auth_backend_ldap, rabbit_auth_backend_internal]}`
- `bob`:`ldap` exists in LDAP backend and has the *administrator* *user tag*
- `bob`:`internal` exists in the internal backend and has the *management* *user tag*

When I try to login with `bob`:`ldap`,
the user is successfully logged in with LDAP authN backend and
RabbitMQ uses LDAP authZ backend to perform further access control.
The user gets granted *admnistrator* *user tag*.
RabbitMQ logs shows LDAP requests to check *user tags* and *vhost* access.

When I try to login with `bob`:`internal`,
the user fails to login with LDAP authN backend (RabbitMQ logs captured `LDAP bind returned "invalid credentials"`) but
succeeds with internal authN backend
And RabbitMQ uses the internal AuthN backend, i.e. the one that authenticated the user, to perform further access control. The user gets granted *management* *user tag*. In other words, it uses the same backend for authN and authZ.
If RabbitMQ would have used the first backend to perform AuthZ, the user would have got *admnistrator* *user tag*.
RabbitMQ logs does not show LDAP requests to check *user tags* and *vhost* access. This probes that LDAP authZ is not used when the user is successfully authenticated by the internal AuthN. 

### Scenario 2
```
{auth_backends, [{rabbit_auth_backend_ldap, rabbit_auth_backend_internal}]}
```

### Scenario 2
```
{auth_backends, [{rabbit_auth_backend_ldap, rabbit_auth_backend_internal}, {rabbit_auth_backend_internal}]}
```


Given this setup
- `{auth_backends, [rabbit_auth_backend_ldap, rabbit_auth_backend_internal]}`
- `bob`:`ldap` exists in LDAP backend and has the *administrator* *user tag*
- `bob`:`internal` exists in the internal backend and has the *management* *user tag*



However with this other setup
- `{auth_backends, [{rabbit_auth_backend_ldap, rabbit_auth_backend_internal}, {rabbit_auth_backend_ldap, rabbit_auth_backend_internal}]} `
- and same users

When I try to login with `bob`:`internal`,
the user is fails to login with LDAP authN and i am not sure if it has logged in with the internal authN backend because
I don't see any LDAP authZ requests in the logs.



I thought RabbitMQ would go again to the list of auth_backends, starting with the first one, in order to perform the authorization.

 `{auth_backends, [rabbit_auth_backend_ldap, rabbit_auth_backend_internal]}`
