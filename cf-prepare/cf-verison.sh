#!/bin/bash

export PATH=/home/vcap/etcdctl/bin:$PATH
source /home/vcap/script/cf-prepare/etcdinit.sh

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

pushd /home/vcap/etcdctl

./build

popd

cf_version=`etcdctl get /deployment/v1/manifest/version`

pushd /home/vcap/

    git clone https://github.com/cloudfoundry/cf-release 
    cd /home/vcap/cf-release
    git submodule update --init
    git pull origin master
    git checkout $cf_version
    
popd
