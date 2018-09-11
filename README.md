

# Prequisites


- The examples assumes RabbitMQ is running locally
- Install Docker. We will use Docker to run **OpenLdap**
- Download latest **bin** release from [RabbitMq Perf Test](https://github.com/rabbitmq/rabbitmq-perf-test)


> TL;DR : With external authz backends like the LDAP one we highly recommend using https://github.com/rabbitmq/rabbitmq-auth-backend-cache in production because under load RabbitMQ is known to hammer LDAP servers hard enough with queries that they can't keep up.

> Make sure the connection timeouts in your LDAP server are larger than your configured timeout (auth_ldap.timeout) otherwise your LDAP server may terminate the connection and the ldap plugin may fail to operate afterwards. 

# Integration scenarios

- [Only Authentication](only-authentication/Readme.md)
- [Authentication and User tags](authentication-and-tags/Readme.md)
- [Authentication, User tags and Vhosts](auth-tags-vhost/Readme.md)
- [Many RabbitMq Clusters](many-rabbitmq-clusters/Readme.md)
