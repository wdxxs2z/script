#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/etcd/bin:$PATH
export GOPATH=/var/vcap/packages/etcd

homedir=/home/vcap
export PATH=/home/vcap/etcdctl/bin:$PATH
RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`
echo "------------ETCD---------------"

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "GOROUTER GIT INIT......"
pushd $homedir/cf-release
cd src/etcd
git submodule update --init
popd

echo "This step will always be install......"
mkdir -p /var/vcap/packages
pushd /var/vcap/packages

echo "Setup git checkout etcd......"
cp -a $homedir/cf-release/src/etcd /var/vcap/packages
cd /var/vcap/packages/etcd 
./build

popd

pushd /var/vcap/packages

mkdir -p /var/vcap/packages/common/

cp -a /home/vcap/cf-release/src/common/* /var/vcap/packages/common/

mkdir -p /var/vcap/packages/syslog_aggregator

cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/

tar -zcf etcd.tar.gz etcd common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@etcd.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr etcd.tar.gz

popd
