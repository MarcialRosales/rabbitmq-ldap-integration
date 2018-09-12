#!/usr/bin/env bash

docker rm -f openldap || echo "OpenLdap was not running"
docker run --env LDAP_ORGANISATION="Authentication and Tags" --env LDAP_DOMAIN="example.com" --env LDAP_ADMIN_PASSWORD="admin" --detach -p 389:389 -p 636:636 --name openldap osixia/openldap:1.2.1
