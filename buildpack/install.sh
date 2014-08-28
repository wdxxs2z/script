#!/bin/bash

homedir=/home/vcap

BUILDPACK_ALL=/var/vcap/packages

export PATH=/home/vcap/etcdctl/bin:$PATH

source /home/vcap/script/buildpack/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

mkdir -p $BUILDPACK_ALL/buildpack_cache

wget -c -r -nd -P $BUILDPACK_ALL/buildpack_cache http://$RESOURCE_URL/packages/buildpack_cache
