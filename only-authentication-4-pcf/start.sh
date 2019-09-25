#!/usr/bin/env bash

# Defaults
ldap_org_default="Authentication and Tags"
rootdn_default="example.com"
userdn_default="People"
admin_user_default="admin"
admin_user_pswd_default="admin"

# Read inputs
read -p "Enter LDAP Organisation [${ldap_org_default}]: " ldap_org
read -p "Enter root domain [${rootdn_default}]: " rootdn

rootdn=${rootdn:-$rootdn_default}

read -p "Enter user DN under ${rootdn} [${userdn_default}]: " userdn
read -p "Enter LDAP admin password [${admin_user_pswd_default}]: " admin_user_pswd


rootdn_fval=$(echo "${rootdn}" |grep -P '.*(?=\.)' -o)
rootdn_lval=$(echo "${rootdn}" |grep -P '[^.]+$' -o)

ldap_org=${ldap_org:-$ldap_org_default}
rootdn=${rootdn:-$rootdn_default}
userdn=${userdn:-$userdn_default}
admin_user=${admin_user:-$admin_user_default}
admin_user_pswd=${admin_user_pswd:-$admin_user_pswd_default}

# Install packages

echo "Installing docker"
systemctl start firewalld
yum -y install openldap-clients
yum -y install docker
yum -y  install docker-compose
systemctl start docker

# Generate user template

export ldap_org admin_user_pswd rootdn userdn rootdn_fval rootdn_lval 
envsubst < userdn.template > userdn.ldif
envsubst < default-users.template > default-users.ldif
docker rm -f openldap || echo "OpenLdap was not running"
docker run  --env LDAP_ORGANISATION="${ldap_org}" --env LDAP_DOMAIN="$rootdn" --env LDAP_ADMIN_PASSWORD="${admin_user_pswd}" --detach -p 389:389 -p 636:636 --name openldap osixia/openldap:1.2.1

echo "Waiting for LDAP server to come up ..."
sleep 10

dn=\"cn=${admin_user},dc=${rootdn_fval},dc=${rootdn_lval}\"
ldapadd -x -h localhost -p 389  -w "${admin_user_pswd}" -D "cn=${admin_user},dc=${rootdn_fval},dc=${rootdn_lval}" -f userdn.ldif
echo "Adding default users"
ldapadd -x -h localhost -p 389  -w "${admin_user_pswd}" -D "cn=${admin_user},dc=${rootdn_fval},dc=${rootdn_lval}" -f default-users.ldif
