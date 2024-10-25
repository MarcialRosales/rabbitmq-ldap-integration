# Configuration query that combines User Tags and Vhost access

Hundreds of users access their clusters via the RabbitMQ management UI. Is there a way to limit acess for e.g. AD Group "mgmt_vhosta" to just vhost "a" and not the whole cluster? 

These are our requirements for this scenario:

- In our `dc=example, dc=com` organization we have 3 vhosts: **dev** and **prod**. Each environment matches one RabbitMQ vhost.
- There are two ldap groups per vhost. For instance, 
    * users in `msg_dev` can access the vhost `dev` via one of the messaging protocols
    * users in `mgt_dev` can access the vhost `dev` via the management UI 

## 1. Launch OpenLDAP

From within `mgt-per-vhost-auth` folder, run `start.sh` script to launch **OpenLDAP**. It will kill the container we ran on the previous scenario and it will start a new one. This is so that we start with a clean LDAP database.

## 2. Set up LDAP entries

* Groups: 
    - `msg_dev` and `mgt_dev`
    - `msg_prod` and `mgt_prod`
* Users:
    - `app100` and `user100` for `dev` vhost
    - `app200` and `user200` for `prod` vhost

```
          dc=example, dc=com
                  |
          +-------+---------+----------------------------------------+
          |                 |                                        |
   cn=admin,            ou=env,                                   ou=People
    dc=example,          dc=example,                               dc=example,
    dc=com               dc=com                                    dc=com
                            |                                        |
  +--------------+---------+-+                              +-------+--------------+
  |              |           |                              |                      |
ou=msg_dev     ou=msg_prod  ou=mgt_dev                      cn=app100      cn=user100,   
 ou=env,       ou=env,      ou=env,                         ou=People,     ou=People, 
 dc=example,   dc=example,  dc=example,                     dc=example,    dc=example
 dc=com        dc=com       dc=com                       
  ||              ||             ||                         
  ||              ||             ||                         
------          ------         ------                       
cn=app100,..    cn=app200      cn=user100,...

```


Run the following command to create this structure:   

```
./mgt-per-vhost-auth/import.sh
```

Run the following command to create the vhosts:  

```
./mgt-per-vhost-auth/create-vhosts.sh
```


### 3. Configure RabbitMQ 

Edit your `rabbimq.config`, add the following configuration and restart RabbitMQ:

```
[
    {rabbit, [
        {auth_backends, [rabbit_auth_backend_ldap]}
    ]},
    {rabbitmq_auth_backend_ldap, [
        {servers,            ["localhost"]},
        {user_dn_pattern,    "cn=${username},ou=People,dc=example,dc=com"},
        {other_bind,         {"cn=admin,dc=example,dc=com", "admin"}},
        {tag_queries, [
            {administrator,  {in_group, "cn=administrator,ou=groups,dc=example,dc=com", "uniqueMember"}},
            {management,     {in_group, "cn=management,ou=groups,dc=example,dc=com", "uniqueMember"}}
        ]},
        {vhost_access_query, {'or', [
                {in_group, "cn=mgt_${vhost},ou=env,dc=example,dc=com", "uniqueMember"},
                {in_group, "cn=msg_${vhost},ou=env,dc=example,dc=com", "uniqueMember"}
            ]} 
        }, 
        {log, network}
    ]}
].
```

This same configuration is available in the file [rabbitmq.config](rabbitmq.config) should you want to copy files.

**Configuration explained**:



### 4. Verify Configuration

1. Make sure that `app100` can access via AMQP to the vhost `dev`
    ```
    ruby app100.rb dev
    ```
2. Make sure that `app100` **cannot** access via AMQP to the vhost `prod`
    ```
    ruby app100.rb prod
    ```
3. Make sure that `app200` can access via AMQP to the vhost `prod`
    ```
    ruby app200.rb prod
    ```
4. Make sure that `app100` cannot access the management plugin
    ```
    curl -u app100:password http://localhost:15672/api/overview`
    ```
    Shall produce:
    ```
    {"error":"not_authorised","reason":"Not management user"}
    ```
