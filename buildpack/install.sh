#!/bin/bash

homedir=/home/vcap

BUILDPACK_ALL=/var/vcap/packages

RESOURCE_URL="192.168.201.134:9090"

mkdir -p $BUILDPACK_ALL/buildpack_cache

wget -c -r -nd -P $BUILDPACK_ALL/buildpack_cache http://$RESOURCE_URL/packages/buildpack_cache
