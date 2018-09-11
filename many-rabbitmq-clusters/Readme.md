# Many RabbitMq Clusters

Can we leverage a single LDAP server to manage the identities of many independent Rabbitmq Clusters?  This is a situation we encounter in the on-demand RabbitMQ Tile in PCF.

## Option 1

Users are defined in LDAP indistinctly of which cluster they are entitled to access.

**RabbitMq topology**:
```

    on-demand-cluster1
      +-- 3 vhosts: /, demo, test  

    on-demand-cluster2
      +-- 1 vhosts: /

    multi-tenant
      +-- 10 vhosts: /, 0001, 0009
```
**RabbitMq configuration & LDAP entries**:
  - All users follow the same DN:
    ```
    user_dn_pattern: cn=${username},ou=users,dc=example,dc=com
    ```
  - Sample users:
    ```
    cn=app1,ou=users,dc=example,dc=com
    cn=app2,ou=users,dc=example,dc=com
    ```
  - Each cluster has its own organizatinal unit:
    ```
      ou=on-demand-cluster1,ou=clusters,dc=example,dc=com
      ou=multi-tenant,ou=clusters,dc=example,dc=com
    ```
  - User permissions to vhosts are done via a group under the corresponding cluster.
    In this example, `app1` can access vhost `0001` on `on-demand-cluster1`
    ```
      cn=0001-users,ou=on-demand-cluster1,ou=clusters,dc=example,dc=com
      members: cn=app1,ou=users,dc=example,dc=com
    ```
    This setup requires each cluster to have its own distinct ldap configuration, specially the `vhost_access_query`.
    For instance, in the cluster `on-demand-cluster1` we would need this query:
    `cn=${vhost}-users,ou=on-demand-cluster1,ou=clusters,dc=example,dc=com`

    whereas for `multi-tenant` we would need this other query:
    `cn=${vhost}-users,ou=multi-tenant,ou=clusters,dc=example,dc=com`


The question for RabbitMq on-demand is how we are going to define the cluster name:
  - Can we use the service instance GUI which is assumed to be unique across all service instances?
  - or do we let the user pass a name via arguments to the `cf create-service`?


## Option 2

Users are defined in LDAP under an organizational unit dedicated to each cluster. In other words, clusters do not share their users. 

**RabbitMq topology**:
```

    on-demand-cluster1
      +-- 3 vhosts: /, demo, test  

    on-demand-cluster2
      +-- 1 vhosts: /

    multi-tenant
      +-- 10 vhosts: /, 0001, 0009
```

**RabbitMq configuration & LDAP entries**:
  - Each cluster has its own organizatinal unit:
    ```
    ou=multi-tenant,dc=example,dc=com
    ou=on-demand-cluster1,dc=example,dc=com
    ```
  - Users on the `multi-tenant` cluster are defined under
    ```
    user_dn_pattern: cn=${username},ou=multi-tenant,dc=example,dc=com
    ```
  - Sample users:
    ```
    cn=app1,ou=multi-tenant,dc=example,dc=com
    cn=app2,ou=on-demand-cluster1,dc=example,dc=com
    ```
