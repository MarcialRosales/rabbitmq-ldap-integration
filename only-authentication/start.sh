#!/usr/bin/env bash


docker run --env LDAP_ORGANISATION="Only authentication" --env LDAP_DOMAIN="example.com" --env LDAP_ADMIN_PASSWORD="admin" --detach -p 389:389 -p 636:636 osixia/openldap:1.2.1
