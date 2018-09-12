# Authentication and Authorization (tags, vhosts, resources)

We expand on the previous scenario, [Authentication, User tags and Vhosts](../auth-tags-vhost/Readme.md), but this time we are going to configure which users get access to which resources -be it *exchange* and/or *queue*- and to do which operation -be it *declare*, *write* (send message to an exchange) and *read* (get or consume message from queue).

These are our requirements for this scenario:
  - Topology we need to support on vhost `dev`.
  ```
      |app100| ---X{app100-x-events}--->Q{app101-q-events}------> |app101|
        /\                                                           |
        |                                                       X{app101-x-requests}    
        |                                                            |
        |                                                       Q{app102-q-requests}
        |                                                            |
        |                                                            \/
  Q{app100-q-confirmations}  <-----X{app102-x-confirmations}------|app102|

  ```
  - General rules:
    - All apps on the topology only has access to vhost `dev`
    - All apps are allowed to do all 3 operations on any exchange and queue that matches the pattern `<appName>-q-.*` for queues and `<appName>-x-.*` for exchanges. In other words, applications can declare the resources they own.
  - `app100` needs to bind its queue `app100-q-confirmations` to the exchange `app102-x-confirmations` therefore it needs *read* access to that exchange.
  - `app101` needs to bind its queue `app101-q-events` to the exchange `app100-x-events` therefore it needs *read* access to that exchange.
  - Likewise, `app102` needs to bind its queue `app102-q-requests` to the exchange `app101-x-requests`.

> From the [docs](http://www.rabbitmq.com/access-control.html#permissions):   
> RabbitMQ distinguishes between configure, write and read operations on a resource. The configure operations create or destroy resources, or alter their behaviour. The write operations inject messages into a resource. And the read operations retrieve messages from a resource.

## 1. Launch OpenLDPA

Run `start.sh` script to launch **OpenLdap**. It will kill the container we ran on the previous scenario and it will start a new one. This is so that we start with a clean LDAP database.

## 2. Set up LDAP entries

We are going to expand the LDAP structure we used in the [previous scenario](../authentication-and-tags/Readme.md) by adding 3 more users : `app101`, `app102` and `admin-dev`

Furthermore, we are going to alter the structure defined in the [previous scenario](../authentication-and-tags/Readme.md) as follows:
1. We are adding one **organizational unit** per vhost: e.g. `ou=dev,ou=env,dc=example,dc=com`
2. We are adding one **groupOfUniqueNames** called `users` per vhost: e.g. this is one for the `dev` vhost `cn=users,ou=dev,ou=env,dc=example,dc=com`
3. We are adding one **groupOfUniqueNames** for each resource and type of operation -be it `configure`, `read` and `write`- when we want to grant access to a resource which is not "owned" by the application that created it.  
For instance, if we want to let user `app101` bind to the exchange `app100-x-events` (which is owned by `app100`) then we need to define an entry with this DN `cn=app100-x-events-read,ou=dev,ou=env,dc=example,dc=com`. And we need to add `app101` as a member of that group.
    > The `read` permission is necessary to bind to an exchange.

This is the resulting LDAP entries after we import them with the command `./import.sh`:  

Very briefly from top to bottom:
  1. At the Root/top is our organization.
  2. From it hangs:  
    - the environments under `ou=env, ...`  
    - all the users/apps under `ou=People,...`  
    - and the LDAP administrator user
  3. From the environments hangs 2 environments:  
    - `ou=dev,...` and  
    - `ou=prod,...`.  
  4. From `dev` environment hangs 3 group (but there could be more):   
    - `cn=users,..` group designate which users have access to this (`dev`) environment  
    - `cn=administrator` group designate which users has the `policymaker` *user tag*  and can also `configure` (i.e. declare and delete) exchanges and queues. In the our scenario, we have chosen `cn=admin-dev,ou=People,..` to administer this environment.  
    - Finally, the resource group called `cn=app100-x-events-read` which allows its members to read on the `app100-x-events` resource. We can create as many resource groups as needed.

```
          dc=example, dc=com
                  |
            +-----+---------+----------------------------------------+
            |               |                                        |
         ou=env,        cn=admin,                                 ou=People
          dc=example,    dc=example,                               dc=example,
          dc=com         dc=com                                    dc=com
            |                                                        |
  +---------+--------------+                                 +-------+--------------+----------------+
            |              |                                 |                      |                |
          ou=dev          ou=prod                           cn=app100    .......   cn=app101,       cn=admin-dev
           ou=env,         ...                               ou=People,             ou=People,       ou=People,
           dc=example,                                       dc=example,            dc=example,      dc=example,
           dc=com                                            dc=com                 dc=com           dc=com
            |
  +---------+----------------------+   
  |         |                      |
cn=users,   cn=administrator       cn=app100-x-events-read
 ou=dev,     ou=dev,                ou=dev,
 ou=env,     ou=env,                ou=env,
 dc=example, dc=example,            dc=example,
 dc=com      dc=com                 dc=com
   ||           ||                     ||
---------     --------              --------        
cn=app100,..   cn=admin-dev,...      cn=app101,....  
cn=app101,..
cn=app102,..
cn=admin-dev,...
```


There are no new vhosts on this scenario. However, run the following command to create the vhosts if you haven't created them yet:  
`./create-vhosts.sh`
> Vhosts must exist in RabbitMQ whereas users and their permissions don't because they are defined in LDAP.


### 3. Configure RabbitMq to authenticate users with our LDAP server and grant administrator and monitoring user tags

Edit your **rabbimq.config**, add the following configuration and restart Rabbit:
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

        {tag_queries, [
               {administrator,  { in_group, "cn=administrator,ou=groups,dc=example,dc=com" , "uniqueMember" }},
               {monitoring,     { in_group, "cn=monitoring,ou=groups,dc=example,dc=com" , "uniqueMember" }},
               {management,     { constant, true }},
               {policymaker,    { in_group, "cn=administrator,ou=${vhost},ou=env,dc=example,dc=com", "uniqueMember" }}
               ]
        },
        {vhost_access_query,    { in_group, "cn=users,ou=${vhost},ou=env,dc=example,dc=com", "uniqueMember" }},
        {resource_access_query,
          { 'or',
            [
              { for, [ { permission, configure, { in_group, "cn=administrator,ou=${vhost},ou=env,dc=example,dc=com", "uniqueMember" } } ]
              },
              { for, [
                      {resource, exchange, { match,
                                                    { string, "${name}" },
                                                    { string, "^${username}-x" }
                                            }
                      },
                      {resource, queue, { match,
                                                    { string, "${name}" },
                                                    { string, "^${username}-q" }
                                            }
                      }
                     ]
              },
              { in_group, "cn=${name}-${permission},ou=${vhost},ou=env,dc=example,dc=com", "uniqueMember" }                
            ]
          }
        },
        {log, network}

      ]
    }
].
```


**Configuration explained**:
- We have granted `management` *user tags* to all users because any developer should be able to at least monitor its queues and exchanges, connections and channels. They will only be able to view the vhosts they are allowed to.
- TODO explain tag_queries for policymaker
- TODO explain resource_access_query


### 4. Verify Configuration

1. Make sure we can successfully run the 3 applications:
  ```
  ruby app100.rb & ruby app101.rb & ruby app102.rb &
  ```
  It should produce this output:
  ```
  app100: ---> Sending event
  app101: -----> Received event
  app101: -----> Sending request
  app102: ----> Received request
  app102: ----> Sending confirmation
  app100: --> Received confirmation
  ```
  > If you get fewer statements it means that we hit a "race condition" whereby publishers like app100
  publishes a message before any queue is bound to it. In production, we should use Alternate Exchanges to deal with
  this type of situations so that we dont loose any messages.


2. Make sure that `app100` cannot publish to `app101-x-requests` exchange
  ```
  ruby publish.rb dev app100 password app101-x-requests
  ```
  Shall produce:
  ```
  /usr/local/lib/ruby/gems/2.3.0/gems/bunny-2.11.0/lib/bunny/channel.rb:1952:in `raise_if_continuation_resulted_in_a_channel_error!': ACCESS_REFUSED - access to exchange 'app101-x-requests' in vhost 'dev' refused for user 'app100', backend rabbit_auth_backend_ldap returned an error: ldap_evaluate_error (Bunny::AccessRefused)
  ```

3. Make sure that `app100` can delete its own resources, .e.g `app100-x-events`
  ```
  rabbitmqadmin  --vhost dev --username app100 --password password delete exchange name="app100-x-events"
  ```

4. Make sure that `admin-dev` can create policies on `dev`
  ```
  rabbitmqadmin  --vhost dev --username admin-dev --password password declare policy name='ttl-policy' \
   pattern='app101-q-events' definition='{"message-ttl":60000}'
  ```
  Check the policy is there:
  ```
  rabbitmqadmin  --vhost dev --username admin-dev --password password list policies
  ```

5. Make sure that `app101` cannot delete resources it does not own, e.g `app102-x-confirmations`
  ```
  rabbitmqadmin  --vhost dev --username app101 --password password delete exchange name="app102-x-confirmations"
  ```
  We should get:
  ```
  *** Access refused: /api/exchanges/dev/app102-x-confirmations
  ```

6. Make sure that `admin-dev` can delete any resource, e.g. `app102-x-confirmations`
  ```
  rabbitmqadmin  --vhost dev --username admin-dev --password password delete exchange name="app102-x-confirmations"
  ```
