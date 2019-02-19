# Many RabbitMQ Clusters

We are going to explore how we can we use a single LDAP server to authenticate RabbitMQ clients across many RabbitMQ Clusters using LDAP. We have sliced the exploration in 2 directions.

**LDAP entries for all RabbitMQ users/clients are defined under an organizational unit(s) independent of the RabbitMQ cluster they belong to**

In this direction all RabbitMQ users/clients are defined under a common organizational unit (flat or hierarchical) separate from the organizational units associated to the RabbitMQ cluster. This direction is further explored in the [Topology 1](#topology-1) section for flat user organization and [Topology 3](#topology-3) section for a hierarchical user organization.

**Advantages**:
- We can easily grant a RabbitMQ client/user (e.g. `cn=joe,ou=users,dc=example,dc=com`) access to multiple RabbitMQ Clusters

**Disadvantage**:
- It makes sense for end users to have them under a single organizational unit however for clients/apps it may be a little bit awkward. We would have to choose a naming scheme to guarantee uniqueness such as `cn=app1-dev,ou=users...` where we combine the application name `app1` with environment's name `dev` where the application is deployed. It is not ideal.


**LDAP entry for a RabbitMQ user/client is defined under a single RabbitMQ Cluster LDAP entry**

This is the second direction of our exploration of LDAP with multiple RabbitMQ Clusters. Here, RabbitMQ users belong to a single RabbitMQ cluster.

**Advantages**:
- Easy to reason about from a security standpoint. To know who is entitled to access a RabbitMQ cluster, indistinctly of the *vhost* they can access, we only need to look at what LDAP entries exists under an LDAP directory, e.g. To know which users can access the cluster `odb-cluster1` we only need to look at what LDAP entries exists under `ou=odb-cluster1,ou=clusters,dc=example,dc=com`. This is the LDAP entry associated to the `odb-cluster1` RabbitMQ Cluster. See [LDAP Organization for Topology 2](#topology-2) for more details.

**Disadvantages**:
- We would have to duplicate the RabbitMQ client/user's LDAP entry if we want to grant access to multiple RabbitMQ clusters.
  > Maybe a third topology would be to separate RabbitMQ clients from RabbitMQ end-users so that RabbitMQ clients are solely defined under its own RabbitMQ cluster whereas RabbitMQ users can be defined elsewhere. With this topology, we have the flexibility of granting an administrator user access to multiple RabbitMQ clusters where as applications will only access their own RabbitMQ cluster.


## Topology 1

Users are defined in LDAP indistinctly of which cluster they are entitled to access and we use group membership to configure which users are allowed to access which RabbitMQ cluster & *vhost*.

### RabbitMQ topology

This is a sample RabbitMQ topology to illustrate this set up. Here we have 3 different RabbitMQ Clusters and each cluster with 1 or many vhosts each.

```
    odb-cluster1
      +-- 3 vhosts: /, demo, test  

    odb-cluster2
      +-- 1 vhosts: /

    multi-tenant
      +-- 10 vhosts: /, 0001, 0009
```

### LDAP organization

This is a sample LDAP organization to match the topology:
```
          dc=example, dc=com
                  |
          +-------+------------+----------------+
          |                                     |
      ou=users                             ou=clusters,
       dc=example,                          dc=example,
       dc=com                                dc=com
          |                                     |
    +-----------+--------------+                +--------------------+--- ....
    |           |              |                |                    |
  cn=app1       cn=app2       cn=joe           ou=odb-cluster1   ou=odb-cluster1
   ou=users,  ou=users,     ou=users,         ou=clusters,        ou=clusters,
   dc=example,  dc=example,   dc=example,      dc=example,        dc=example,
   dc=com       dc=com        dc=com           dc=com             dc=com
                                                |
                                        +-------+--------+
                                        |
                                    cn=demo-users,
                                    ou=odb-cluster1,
                                    ou=clusters,       
                                    dc=example,
                                    dc=com
                                    ==members=========
                                    cn=app1,ou=users,dc=example,dc=com
```

  - All users are under the same organizational unit
    ```
    ou=users,dc=example,dc=com
    ```
  - Sample users (client apps like `app1` and end users like `joe`):
    ```
    cn=app1,ou=users,dc=example,dc=com
    cn=app2,ou=users,dc=example,dc=com
    cn=joe,ou=users,dc=example,dc=com
    ```
  - All clusters are under the same organizational unit
    ```
    ou=clusters,dc=example,dc=com
    ```
  - Each cluster has its own organizatinal unit:
    ```
    ou=odb-cluster1,ou=clusters,dc=example,dc=com      
    ```
    > The cluster name, e.g. `odb-cluster1`, can be RabbitMQ's cluster name or any other arbitrary name.

  - There is an LDAP group defined per each *vhost* under its cluster. Here we have the `demo`
  *vhost* under the `odb-cluster1` RabbitMQ cluster. The group has a `members` attribute which has
  all the users' DN which are entitled to access the *vhost*, such as `cn=app1,ou=users,dc=example,dc=com`.
    ```
      cn=demo-users,ou=odb-cluster1,ou=clusters,dc=example,dc=com
      members: cn=app1,ou=users,dc=example,dc=com
    ```

### RabbitMQ configuration
  - Look up users following the DN below. For authentication purposes, RabbitMQ binds to LDAP server using the user's credentials (i.e. *username* and *password*):
    ```
    user_dn_pattern: cn=${username},ou=users,dc=example,dc=com
    ```
  - User permissions to vhosts are done via a LDAP group under the corresponding cluster. This setup requires each cluster to have its own distinct LDAP configuration, specially the `vhost_access_query`.
    For instance, in the cluster `odb-cluster1` we would need this `vhost_access_query`:
    `cn=${vhost}-users,ou=odb-cluster1,ou=clusters,dc=example,dc=com`

    whereas for `multi-tenant` we would need this other `vhost_access_query`:
    `cn=${vhost}-users,ou=multi-tenant,ou=clusters,dc=example,dc=com`


## Topology 2

RabbitMQ clients/users are defined in LDAP under an organizational unit dedicated to each cluster. In other words, clusters do not share their users.

### RabbitMQ topology

This is a sample RabbitMQ topology to illustrate this set up. Here we have 3 different RabbitMQ Clusters and each cluster with 1 or many vhosts each.

```
    on-demand-cluster1
      +-- 3 vhosts: /, demo, test  

    on-demand-cluster2
      +-- 1 vhosts: /

    multi-tenant
      +-- 10 vhosts: /, 0001, 0009
```

### LDAP organization

This is a sample LDAP organization to match the topology:
```
          dc=example, dc=com
                  |
          +-------+------------+----------------+
          |                                     |
                                            ou=clusters,
                                            dc=example,
                                            dc=com
                                                |
                                                +--------------------+--- ....
                                                |                    |
                                                ou=odb-cluster1,   ou=odb-cluster1,
                                                ou=clusters,        ou=clusters,
                                                dc=example,        dc=example,
                                                dc=com             dc=com
                                                |
                                    +-----------+--------+
                                    |                    |
                                  cn=app1,           cn=demo-users,
                                  ou=odb-cluster1,   ou=odb-cluster1,
                                  ou=clusters,       ou=clusters,
                                  dc=example,        dc=example,
                                  dc=com             dc=com
                                                     ===members=====
                                                     cn=app1,ou=odb-cluster1,ou=clusters,dc=example,dc=com
```
  - All clusters are under the same organizational unit
    ```
    ou=clusters,dc=example,dc=com
    ```
  - Each cluster has its own organizatinal unit:
    ```
    ou=odb-cluster1,ou=clusters,dc=example,dc=com
    ```
  - Users are defined under the RabbitMQ cluster they belong to
    ```
    cn=app1,ou=odb-cluster1,ou=clusters,dc=example,dc=com
    ```
  - User permissions to vhosts are done via a group under the corresponding cluster.
    In this example, `app1` can access vhost `demo` on `odb-cluster1`
    ```
      cn=demo-users,ou=odb-cluster1,ou=clusters,dc=example,dc=com
      members: cn=app1,ou=odb-cluster1,ou=clusters,dc=example,dc=com
    ```

### RabbitMQ configuration

  - Look up users following the DN below. For authentication purposes, RabbitMQ binds to LDAP server using the user's credentials (i.e. *username* and *password*):
    ```
    user_dn_pattern: cn=${username},ou=odb-cluster1,ou=clusters,dc=example,dc=com
    ```
  - This setup requires each cluster to have its own distinct LDAP configuration, specially the `vhost_access_query`.
    For instance, in the cluster `odb-cluster1` we would need this query:
    `cn=${vhost}-users,ou=odb-cluster1,ou=clusters,dc=example,dc=com`

    whereas for `multi-tenant` we would need this other query:
    `cn=${vhost}-users,ou=multi-tenant,ou=clusters,dc=example,dc=com`



## Topology 3

Users are defined under a tree of *organizational unit*(s) independent from the *organizational units* dedicated to RabbitMQ cluster. To model which users are allowed to access which RabbitMQ clusters we use LDAP group membership. Users' roles can be defined using LDAP groups and/or attributes. In this topology we have used the latter however if you wanted to see how it is model with groups check out [Authentication, User tags and Vhosts](auth-tags-vhost/README.md) scenario.

### RabbitMQ topology

This is a sample RabbitMQ topology to illustrate this set up. Here we have 3 different RabbitMQ Clusters where there is only one **vhost** per RabbitMQ cluster (similar to what happens with [On-demand RabbitMQ for PCF](https://docs.pivotal.io/rabbitmq-cf/1-15/use.html)).

```
    odb-cluster1
      +-- vhost: 3a2a9f

    odb-cluster2
      +-- vhost: 72e0dd

```

> Given this configuration where there wont be more than one vhost, we dont necessarily need to configure a vhost-access-query. In other words, every user has access to any vhost even though there wont be more than one.

### LDAP organization

This is a sample LDAP organization to match the topology. We have split the ldap tree into 2 diagrams.

```
          dc=example, dc=com
                  |
          +-------+--------
          |                
      ou=People          
       dc=example,        
       dc=com              
          |
          +-------+------------+----------------+-----------------
          |                    |                |
       ou=employees       ou=contractors,   ou=service_accounts,
       ou=People          ou=People,        ou=People,
       dc=example,         dc=example,        dc=example,
       dc=com              dc=com             dc=com
          |                    |                |
          |                    |                |
  +-------+-----+              +                +------------------------+
  |             |              |                |                        |
cn=bob         cn=bill       cn=joe           ou=finance              ou=integration,
ou=employees,  ou=employees, ou=contractors,  ou=service_accounts,    ou=service_accounts,
ou=People,     ou=People,    ou=People,       ou=People,              ou=People,
dc=example,    dc=example,   dc=example,      dc=example,             dc=example,
dc=com         dc=com        dc=com           dc=com                  dc=com
------                                          +                        +  
employeeType=administrator                      |                        |                         
                                              cn=app1,                 cn=app2,
                                              ou=finance,              ou=integration,
                                              ou=service_accounts,     ou=service_accounts,
                                              ou=People,               ou=People,
                                              dc=example,              dc=example,
                                              dc=com                   dc=com
```     

```
          dc=example, dc=com
                  |
          +-------+------------+----------------+
                                                |
                                            ou=clusters,
                                            dc=example,
                                            dc=com
                                                |
                                        +-------+------------+--- ....
                                        |                    |
                                    cn=o3a2a91,           cn=3a2a92,
                                    ou=clusters,          ou=clusters,
                                    dc=example,           dc=example,
                                    dc=com                dc=com
                                  ===members=====         ===members=====
                                  cn=app1,ou=finance,...  cn=app2,ou=integration,...
                                  cn=bob,ou=employees,..  cn=bill,ou=employees,...
```

- All clusters are under a common *organizational unit* `ou=clusters,dc=example,dc=com`. However, if needed, we can further structure them into sub *Organizational units*.  
- A cluster is modelled as an LDAP group. For instance, `cn=o3a2a91,ou=clusters,...` has 2 members: a end-user (`cn=bob`) and an service-account (`cn=app1,ou=finance`) from the `finance` *organizational unit*.
- All users must have a common attribute. In our example, we chose `mail` given that all our users have the objectType inetOrgPerson`
- Users with the attribute `employeeType` equal to `administrator` will grant them access to any cluster as `administrator`. `cn=bob,ou=employees,...` is the only user with the `administrator` role.


### RabbitMQ configuration

- During the authentication flow, bind with LDAP user `cn=admin,dc=example,dc=com` and password `admin` to look up RabbitMQ user based on the LDAP `mail` attribute starting from `ou=People,dc=example,dc=com`. It is highly recommended to create a separate user who only has *search* and *read* access under `ou=People,dc=example,dc=com` branch.
  ```
        {dn_lookup_attribute, "mail"},
        {dn_lookup_base,      "ou=People,dc=example,dc=com"},
        {dn_lookup_bind,      {"cn=admin,dc=example,dc=com", "admin"}},
  ```
- To access any *vhost* in the cluster, the user must be a member of the cluster's LDAP group:
  ```
        {vhost_access_query,  {in_group, "cn=o3a2a91,ou=clusters,dc=example,dc=com", "uniqueMember"}}
  ```
- All users with access to the cluster (controlled by `vhost_access_query`) have access to the management UI with `management` *user tag*. And all users who have the attribute `employeeType` with value `administrator` have also access to the management UI with `administrator` *user tag*:
  ```
        {tag_queries, [
            {administrator,  {equals, {attribute, "${user_dn}", "employeeType"},
                                      {string, "administrator" }},
            {management,     {constant, true}}
        ]},
  ```
