#!/bin/bash

echo "**********************************************"
echo "            register monit                    "
echo "**********************************************"

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

source /home/vcap/script/monit/edit_monit.sh

export PATH=/home/vcap/etcdctl/bin:$PATH

#localhost
NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

#monitserver
MONIT_SERVER=$(etcdctl get /deployment/v1/manifest/monitserver)

#acl
MONIT_ACL=$(etcdctl get /deployment/v1/manifest/monitacl)

#monitpasswd
MONIT_PASSWD=$(cat /dev/urandom | head -1 | md5sum | head -c 16)

edit_monit "$NISE_IP_ADDRESS" "$MONIT_SERVER" "$MONIT_ACL" "$MONIT_PASSWD"
