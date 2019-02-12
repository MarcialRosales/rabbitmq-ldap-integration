# Cache Authentication and Authorization backend results

The scenarios we have seen so far such as [Hierarchical user organization](../hierarchical-user-organization/README.md) resolves every auth/z request with the configured backends. If the backends are external like LDAP, it is highly recommended to cache the results specially in production environments. Under load RabbitMQ is known to hammer LDAP servers hard enough with queries that they can't keep up.

## 1. Launch OpenLDAP

We will use the [Hierarchical user organization](../hierarchical-user-organization/README.md) scenario to set up **OpenLDAP**.

Run `hierarchical-user-organization/start.sh` script to launch **OpenLDAP**. It will kill the container we ran on the previous scenario and it will start a new one. This is so that we start with a clean LDAP database.

## 2. Set up LDAP entries

Run the following command to create the LDAP structure shown in the diagram:

```
./hierarchical-user-organization/import.sh
```

It creates 4 users under their respective departments. The users' password is `password`.

### 3. Configure RabbitMQ

Edit your `rabbimq.config`, add the following configuration and restart RabbitMQ:
```
[
    {rabbit, [
        {auth_backends,       [rabbit_auth_backend_cache]}
    ]},
    {rabbitmq_auth_backend_ldap, [
        {servers,             ["localhost"]},
        {dn_lookup_attribute, "mail"},
        {dn_lookup_base,      "dc=example,dc=com"},
        {dn_lookup_bind,      {"cn=admin,dc=example,dc=com", "admin"}},
        {tag_queries, [
            {administrator,   {constant, true}},
            {management,      {constant, true}}
        ]},
        {vhost_access_query,  {constant, true}},
        {log, network_unsafe}
    ]},
    {rabbitmq_auth_backend_cache, [
        {cached_backend,      rabbit_auth_backend_ldap},
        {cache_ttl,           60000}
    ]}
].
```

Edit your `/etc/rabbitmq/enabled_plugins`, add `rabbitmq_auth_backend_cache` to the list:
```
[rabbitmq_auth_backend_cache,rabbitmq_auth_backend_ldap,rabbitmq_management,rabbitmq_management_agent].
```

> For your convenience, there is a [rabbitmq.config](rabbitmq.config) file with this configuration.

**Configuration explained**:
- `rabbit_auth_backend_cache` should be the only configured `auth_backends` under `rabbit`
- We add a new configuration entry called `rabbitmq_auth_backend_cache`, which configures under the attribute `cached_backend` the *auth backends* we had previously configured under `rabbit.auth_backends`. In our case, it is just `rabbit_auth_backend_ldap` backend
- We can configure the TTL for cached authz results, by using `cache_ttl` in milliseconds

> It is possible to configure the cache implementation module, i.e. the internal data structure. However, in this guide we won't get to that. You can get more information [here](https://github.com/rabbitmq/rabbitmq-auth-backend-cache#cache-configuration).


### 4. Verify Configuration

1. Make sure that `bob` can still access the Management API using its email address `bob@example.com`
  ```
  curl -u bob@example.com:password http://localhost:15672/api/overview | jq .
  ```
2. Make sure that RabbitMQ is actually caching authz results.

  First, open the following [link](http://localhost:15672/#/login/bob%40example.com/password) in your browser. And then tail the rabbitmq logs (`tail -f /usr/local/var/log/rabbitmq/rabbit@localhost.log`) and make sure that you only see statements like this one `LDAP CHECK: login for bob@example.com` every minute and not every 5 seconds which is the default refresh frequency of the RabbitMQ management ui.  
