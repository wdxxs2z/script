#!/bin/bash

echo "**********************************************"
echo "            register monit                    "
echo "**********************************************"

cfscriptdir=/home/vcap/cf-dep-configuration
homedir=/home/vcap

export PATH=/home/vcap/etcdctl/bin:$PATH

source /home/vcap/script/util/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

if [ -f /var/vcap/monit/monit.user ]
then
    MONIT_PASSWD=$(more /var/vcap/monit/monit.user | cut -f 2 -d ':')
else
    MONIT_PASSWD=$(cat /dev/urandom | head -1 | md5sum | head -c 16)
fi

#localhost
NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

#monitserver
MONIT_SERVER=$(etcdctl get /deployment/v1/manifest/monitserver)

#acl
MONIT_ACL=$(etcdctl get /deployment/v1/manifest/monitacl)

source /home/vcap/script/monit/edit_monit.sh
edit_monit "$NISE_IP_ADDRESS" "$MONIT_SERVER" "$MONIT_ACL" "$MONIT_PASSWD"
