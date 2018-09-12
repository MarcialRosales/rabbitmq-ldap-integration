#!/usr/bin/env bash

docker rm -f openldap || echo "OpenLdap was not running" && echo "Stopped OpenLdap"
