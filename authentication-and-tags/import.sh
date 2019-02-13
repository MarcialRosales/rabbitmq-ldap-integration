#!/usr/bin/env bash

ldapadd -x -w admin -f import.ldif

#ldapadd -x -w admin -f add-rabbitmq.ldif
#ldapmodify -x -w admin -f grant-rabbitmq.ldif
