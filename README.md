# Prequisites


- RabbitMQ is running locally (localhost:5672 and localhost:15672)
- Docker is installed. We will use Docker to run **OpenLdap**
- Ruby is installed. We will use it to run some AMQP clients.
- Python is installed. We will use it to run [rabbitmqadmin](https://www.rabbitmq.com/management-cli.html)
- `rabbitadmin` is installed.  Go to [http://localhost:15672/cli/rabbitmqadmin](http://localhost:15672/cli/rabbitmqadmin]), copy the downloaded file to your preferred location in your `PATH`
- Download latest **bin** release from [RabbitMq Perf Test](https://github.com/rabbitmq/rabbitmq-perf-test)

TL;DR : With external authz backends like the LDAP one we highly recommend using https://github.com/rabbitmq/rabbitmq-auth-backend-cache in production because under load RabbitMQ is known to hammer LDAP servers hard enough with queries that they can't keep up.

Make sure the connection timeouts in your LDAP server are larger than your configured timeout (`auth_ldap.timeout`) otherwise your LDAP server may terminate the connection and the LDAP plugin may fail to operate afterwards. RabbitMQ 3.7.6 and later versions have addressed these re-connection issues.

>>>>>>> 7a62238... Suggested changes to only-authentication/Readme.md
# Integration scenarios

- [Only Authentication](only-authentication/Readme.md)
- [Authentication and User tags](authentication-and-tags/Readme.md)
- [Authentication, User tags and Vhosts](auth-tags-vhost/Readme.md)
- [Authentication and Authorization (tags, vhosts, resources)](auth-and-authz/Readme.md)
- [Many RabbitMq Clusters](many-rabbitmq-clusters/Readme.md)

# Best Practices | Recommendations

In addition to all the recommendations done in the [rabbitmq ldap documentation](https://www.rabbitmq.com/ldap.html), it is worth keeping an eye on these other ones.

## Use rabbitmq-auth-backend-cache
With external authz backends like the LDAP one we highly recommend using https://github.com/rabbitmq/rabbitmq-auth-backend-cache in production because under load RabbitMQ is known to hammer LDAP servers hard enough with queries that they can't keep up.

## Properly configure LDAP timeouts
Make sure the connection timeouts in your LDAP server are larger than your configured timeout (auth_ldap.timeout) otherwise your LDAP server may terminate the connection and the ldap plugin may fail to operate afterwards.

## Monitor log file to detect when RabbitMQ lost connection with LDAP server
TODO : Add more sample log statements and the minimum configuration to enable it
```
[warning] <0.1777.0> HTTP access denied: rabbit_auth_backend_ldap failed authenticating bob: ldap_connect_error
```
