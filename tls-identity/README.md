# Retrieve RabbitMQ's client identity from the client's certificate

In this scenario, we are going to demonstrate how RabbitMQ clients can use their SSL certificate to authenticate (without *password*) rather than using *username/password*.

In order to RabbitMQ clients authenticate with their SSL certificates, they must connect over AMQPS. And the RabbitMQ server must enable AMQPS and configured to verify the client/peer SSL certificate. This is also known as mutual TLS authentication.

RabbitMQ clients no longer need a password just an SSL Certificate and RabbitMQ would extract the username from the SSL Certificate. More concretely, RabbitMQ will extract the username from the certificate's *Subject* field.

**Deployment scenario - Everyone uses SSL certificates**

We may find environments where end users and applications must have a valid SSL certificate in order to access RabbitMQ.
In this scenario, we must issue an SSL certificate to everyone, that is, end users and applications. *username/password* authentication mechanism is no longer supported.

In this scenario, we disable `PLAIN` and `AMQPLAIN` *auth mechanisms* and enable only `EXTERNAL`.
```
[
  {rabbit, [
    {auth_mechanisms, ['EXTERNAL']}
  ]}
].
```

**Deployment scenario - Except management users, everyone else uses SSL Certificates**

In the contrary, we may find environments where end users and internal applications use username/password to access the management ui and amqp protocol respectively. Whereas external applications authenticate themselves using their SSL certificate over amqps protocol.

In this scenario, we need to support both *auth mechanism*, i.e. `PLAIN` for *username/password* and `EXTERNAL` for SSL Certificates.

```
[
  {rabbit, [
    {auth_mechanisms, ['PLAIN', 'AMQPLAIN', 'EXTERNAL']}
  ]}
].
```

## Deployment scenario to set up

To demonstrate how to use SSL Certificates as *auth mechanism* we are going to use the following combined deployment scenario:
- End users coming over http onto the Management UI must authenticate using *username/password* (i.e. `PLAIN` auth mechanism)
- Clients coming over AMQP are authenticated using *username/password*
- Clients coming over AMQPS are authenticated using *certificates* (i.e. `EXTERNAL` auth mechanism)




There are two options on how RabbitMQ can extract the username from the client's certificate:
- One way is to use the *distinguished name* found in the Certificate's *Subject* field
- The other is to extract the *common name* (`CN`) from the Certificate's *Subject* field


## Authenticating Cloud Foundry Application using SSL Certificates
Starting in [PCF 1.12](https://docs.pivotal.io/pivotalcf/1-12/installing/highlights.html#app-identity), the [Pivotal Application Service](https://pivotal.io/platform/pivotal-application-service) tile issues a unique certificate for each running app instance. The certificate is valid for only 24 hours. See a sample certificate below:



```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            32:2f:a1:3a:25:d8:4b:ab:4b:8b:e5:a7:af:41:fc:d8
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=USA, O=Cloud Foundry, CN=instanceIdentityCA
        Validity
            Not Before: Feb 12 11:49:38 2019 GMT
            Not After : Feb 13 11:49:38 2019 GMT
        Subject: OU=organization:cc46888c-f928-46d2-85f3-eb880fa64928, OU=space:31076a28-4972-416e-9997-c2a89f86f891, OU=app:7f8a6fbf-cb8d-414a-bf93-368debea8a7c, CN=ae868549-6c39-4c9b-68e7-8b8f
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:be:2b:07:93:58:7a:66:a4:5a:a4:b7:69:60:1a:
                    b2:b5:1d:4f:53:f1:ef:71:83:c9:bd:a6:77:c3:3b:
                    b3:03:27:57:28:11:92:e4:3c:fa:01:66:9d:78:59:
                    77:3b:30:26:55:d8:30:ed:9d:d4:b1:d0:e4:3e:19:
                    dd:fe:76:7a:6a:54:a0:30:74:72:79:29:2d:d2:f2:
                    a5:bc:55:5b:13:d2:ef:04:ed:44:7f:47:37:a1:76:
                    f4:dc:93:e8:47:45:c9:14:66:7d:ae:33:1c:97:dd:
                    17:af:5f:c5:30:1d:19:23:9a:b3:7b:0d:ef:a5:03:
                    6d:89:f5:9a:20:50:16:6c:0f:2e:d2:b4:54:1a:27:
                    99:ea:9e:4f:05:0a:4b:62:aa:e5:16:8d:bd:09:e8:
                    a4:3d:ec:ce:98:39:07:68:33:7e:51:fd:4a:29:05:
                    17:ab:53:a3:76:32:3d:b8:1d:24:1f:68:96:cd:51:
                    c0:0f:d2:99:f1:da:af:73:63:79:54:09:d9:c2:8c:
                    e4:92:6d:c9:25:85:88:70:03:b5:2b:6c:72:ba:12:
                    6b:75:55:2f:5e:df:43:ae:01:81:7c:25:52:0f:28:
                    a4:09:45:2e:a1:2d:02:4a:4e:a5:c7:34:07:db:62:
                    c4:7e:ac:dd:c3:73:30:eb:86:27:f0:35:e2:94:e0:
                    00:4f
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Extended Key Usage:
                TLS Web Client Authentication, TLS Web Server Authentication
            X509v3 Subject Alternative Name:
                DNS:ae868549-6c39-4c9b-68e7-8b8f, IP Address:10.255.216.44
    Signature Algorithm: sha256WithRSAEncryption
         2e:dd:3d:7b:8c:8d:50:34:a2:c8:65:e7:bd:e9:3c:ef:2f:df:
         a0:01:66:d3:98:5b:19:bf:97:5f:03:5c:07:02:19:41:75:d1:
         f3:f3:02:7a:c8:4e:4f:9b:d5:fb:52:05:2b:12:c8:33:94:3f:
         1f:dc:f2:72:33:3e:6f:82:71:06:41:3b:61:20:6a:a2:bf:0f:
         22:1e:21:9d:70:b6:03:ba:71:c2:40:d5:16:7b:2e:a0:75:09:
         46:ee:a1:d4:4d:dc:da:f8:19:0b:7e:a0:90:bb:2c:8c:39:f2:
         a2:3c:29:ea:9c:bb:65:74:a3:f1:2f:9c:ff:6c:c0:4c:03:38:
         ec:8e:f6:4c:e2:77:3f:18:2d:33:90:e7:57:20:ba:be:54:6c:
         f9:de:d9:ac:bf:28:2a:9e:63:74:44:51:04:00:e3:30:8d:20:
         1f:1b:f5:b2:7f:3b:e1:44:6d:b9:f9:3e:d3:36:0c:41:b6:36:
         2e:b0:98:ba:c5:a5:86:66:ec:93:97:af:14:c8:f7:87:e4:dc:
         38:90:ab:96:77:6e:aa:0f:66:54:6c:be:6f:94:45:c3:06:30:
         28:92:1e:17:6b:c4:0c:9f:6d:d9:0e:18:f4:7b:29:6f:78:1e:
         10:e3:8e:33:c4:68:fc:dc:83:60:e0:ac:bb:16:38:d4:37:4f:
         24:f4:2d:eb
```

The `CN` contains the application instance ID. Whereas the last `OU`, `OU=app:7f8a6fbf-cb8d-414a-bf93-368debea8a7c` contains the application ID. We are interested in an application identifier not an an application instance identifier. The `DNS` attribute is not useful either, nor the `IP Address` field found in the `Subject Alternative Name` of the certificate.

However, whether we use the *common name* or *distinguish name*, both contains the application instance ID which we are not interested in.
- If we were to use *common name*, the username would be `ae868549-6c39-4c9b-68e7-8b8f`
- If we were to use *distinguished name*, the username would be `CN=ae868549-6c39-4c9b-68e7-8b8f,OU=app:7f8a6fbf-cb8d-414a-bf93-368debea8a7c+OU=space:31076a28-4972-416e-9997-c2a89f86f891+OU=organization:cc46888c-f928-46d2-85f3-eb880fa64928`

In conclusion, we would not be able to use the *Cloud Foundry Application certificate* to extract the application's identity.
