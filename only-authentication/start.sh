#!/usr/bin/env bash


docker run --env LDAP_ORGANISATION="Only authentication" --env LDAP_DOMAIN="example.com" --env LDAP_ADMIN_PASSWORD="admin" --detach osixia/openldap:1.2.1

