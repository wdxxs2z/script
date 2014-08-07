#!/bin/bash

echo "**********************************************"
echo "            build postgresql                  "
echo "**********************************************"

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    pushd $homedir
    git clone https://github.com/cloudfoundry/cf-release
    cd $homedir/cf-release
    git checkout c4dfff2
    git submodule update --init
    popd
fi

#----------------- etcd init --------------------------

source /home/vcap/script/postgres/etcdinit.sh

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

pushd /home/vcap/etcdctl

./build

popd

#----------------- postgresql init ---------------------
if [ ! -d /var/vcap/packages/postgres ]; then
    mkdir -p /var/vcap/packages/postgres
fi

pushd /var/vcap/packages

wget http://192.168.201.128:9090/packages/postgres/postgres-9.0.3-1.amd64.tar.gz

tar xzf postgres-9.0.3-1.amd64.tar.gz -C postgres

tar -zcvf postgres.tar.gz postgres

curl -F "action=/upload/build" -F "uploadfile=@postgres.tar.gz" http://192.168.201.128:9090/upload/build

rm -fr postgres-9.0.3-1.amd64.tar.gz postgres.tar.gz

popd

echo "Postgresql build ok!"
