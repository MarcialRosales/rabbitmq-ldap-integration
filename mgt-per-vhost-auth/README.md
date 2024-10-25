# Configuration query that combines User Tags and Vhost access

The scenario is the following. There could be hundreds of users accessing their clusters via the RabbitMQ management UI. Only users which belong to the ldap group `mgt_dev` have access to only vhost `dev`. Likewise, users which belong to the group `mgt_prod` have access to only the vhost `prod`. 
However, administrator users have full access to all vhosts in the management UI. 

The LDAP and RabbitMQ configuration files are located in the folder `mgt-per-vhost-auth`. 

## 1. Launch OpenLDAP

To launch Openldap, run the following command from the root of this repository:
```bash
make start-ldap 
```

## 2. Set up LDAP entries

Run the following command to import all the ldap definitions used by this scenario:
```bash
make import-ldap FILE=mgt-per-vhost-auth/import.ldif
```

It declares the following entries:
* Groups: 
    - `msg_dev` this group has all the applications who have access to the `dev` vhost 
    - `mgt_dev` this group has all the users who have access to the `dev` vhost via the management UI
    - Likewise for `msg_prod` and `mgt_prod`
    - `management` this group has all users with the user-tag `management`. User-tags are not bound to any vhost. A user-tag only grants that user access to the management UI with a role. To limit the access to any vhost is done thru the `vhost_access_query`. In other words, for user `user100` to be be able to access vhost `dev` in the management UI, it must have the `management` user-tag and must have access to the vhost `dev`. 
    - `administrator` this group has all users with the user-tag `administrator`
* Users:
    - `app100` and `user100` for `dev` vhost
    - `app200` and `user200` for `prod` vhost
 
```
          dc=example, dc=com
                  |
          +-------+---------+----------------------------------------+
          |                 |                                        |
   cn=admin,             ou=groups,                                ou=People
    dc=example,          dc=example,                               dc=example,
    dc=com               dc=com                                    dc=com
                            |                                        |
  +--------------+---------+-+                              +-------+--------------+
  |              |           |                              |                      |
ou=msg_dev     ou=msg_prod  ou=mgt_dev                      cn=app100      cn=user100,   
 ou=groups,    ou=groups,   ou=groups,                      ou=People,     ou=People, 
 dc=example,   dc=example,  dc=example,                     dc=example,    dc=example
 dc=com        dc=com       dc=com                       
  ||              ||             ||                         
  ||              ||             ||                         
------          ------         ------                       
cn=app100,..    cn=app200      cn=user100,...

```

### 3. Deploy RabbitMQ 

To deploy RabbitMQ, run the following command:
```bash
MODE=mgt-per-vhost-auth make start-rabbitmq
```

It deploys RabbitMQ with these two configuration files:
- [mgt-per-vhost-auth/rabbitmq.conf](mgt-per-vhost-auth/rabbitmq.conf) which configures 
ldap as the main authentication backend and a definitions file with two vhosts required
for this scenario.
- [mgt-per-vhost-auth/advanced.config](mgt-per-vhost-auth/advanced.config) which configures
the ldap plugin.


```
[
    {rabbitmq_auth_backend_ldap, [
        {servers,            ["ldap"]},
        {user_dn_pattern,    "cn=${username},ou=People,dc=example,dc=com"},
        {other_bind,         {"cn=admin,dc=example,dc=com", "admin"}},
        {tag_queries, [
            {administrator,  {in_group, "cn=administrator,ou=groups,dc=example,dc=com", "uniqueMember"}},
            {management,     {in_group, "cn=management,ou=groups,dc=example,dc=com", "uniqueMember"}}
        ]},
        {vhost_access_query, {'or', [
                {in_group, "cn=mgt_${vhost},ou=groups,dc=example,dc=com", "uniqueMember"},
                {in_group, "cn=msg_${vhost},ou=groups,dc=example,dc=com", "uniqueMember"}
            ]} 
        }, 
        {resource_access_query,
            {for, [{permission, write, {constant, true}},
                   {permission, read,  {constant, true}},
                   {permission, configure,  {constant, true}}
            ]
        }},        
        {log, network}
    ]}
].
```


### 4. Verify Administrator access in the management ui 

1. Open http://localhost:15672 
2. Enter the credentials `superuser`:`password`
3. You are accessing the management UI as administrator and have access to 
all vhosts and to the majority of options in the Admin tab


### 5. Verify Management access to the dev vhost only in the management ui 

1. Open http://localhost:15672 
2. Enter the credentials `user100`:`password`
3. You are accessing the management UI with limitted access (`management` only) 
and only have access to the `dev` vhost

### 6. Verify Management access to the prod vhost only in the management ui 

1. Open http://localhost:15672 
2. Enter the credentials `user200`:`password`
3. You are accessing the management UI with limitted access (`management` only) 
and only have access to the `prod` vhost

### 7. Verify access over to AMQP protocol

Run the following command:
```bash
make start-perftest-producer USERNAME=app100 PWD=password VHOST=dev
```
`app100` is the credentials used by an application grants access to the `dev` vhost. 

