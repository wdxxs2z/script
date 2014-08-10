#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/hm9000/bin:$PATH
export GOPATH=/var/vcap/packages/hm9000

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "HM9000 GIT INIT......"
pushd $homedir/cf-release
cd src/hm9000
git submodule update --init
popd

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages

    echo "Setup git checkout hm9000......"
    cp -a $homedir/cf-release/src/hm9000 /var/vcap/packages
    cd $GOPATH/src/github.com/cloudfoundry/hm9000
    go build
    cp ./hm9000 /var/vcap/packages/hm9000/
    popd

pushd /var/vcap/packages

mkdir -p /var/vcap/packages/common/

cp -a /home/vcap/cf-release/src/common/* /var/vcap/packages/common/

mkdir -p /var/vcap/packages/syslog_aggregator

cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/

tar -zcvf hm9000.tar.gz hm9000 common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@hm9000.tar.gz" http://192.168.201.128:9090/upload/build

rm -fr hm9000.tar.gz
popd

popd


