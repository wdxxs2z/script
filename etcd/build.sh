#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/etcd/bin:$PATH
export GOPATH=/var/vcap/packages/etcd

homedir=/home/vcap

echo "------------ETCD---------------"

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chwon vcap:vcap /var/vcap
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

tar -zcvf etcd.tar.gz etcd

curl -F "action=/upload/build" -F "uploadfile=@etcd.tar.gz" http://192.168.201.128:9090/upload/build

rm -fr etcd.tar.gz

popd
