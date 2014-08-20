#!/bin/bash

homedir=/home/vcap

BUILDPACK_ALL=/var/vcap/packages

export PATH=/home/vcap/etcdctl/bin:$PATH

RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

mkdir -p $BUILDPACK_ALL/buildpack_cache

wget -c -r -nd -P $BUILDPACK_ALL/buildpack_cache http://$RESOURCE_URL/packages/buildpack_cache
