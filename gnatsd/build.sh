#!/bin/bash

echo "**********************************************"
echo "            build gnatsd                      "
echo "**********************************************"

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/gnatsd/bin:$PATH
export GOPATH=/var/vcap/packages/gnatsd

homedir=/home/vcap

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "GNATSD GIT INIT......"
pushd $homedir/cf-release
cd src/gnatsd
git submodule update --init
popd

#----------------- build install ------------------------
echo "This step will always be install......"
mkdir -p /var/vcap/packages

pushd /var/vcap/packages

    echo "Setup git checkout gonatsd......"
    cp -a $homedir/cf-release/src/gnatsd /var/vcap/packages
    mkdir -p /var/vcap/packages/gnatsd/src/github.com/apcera/gnatsd
    cp -a $homedir/cf-release/src/gnatsd/* /var/vcap/packages/gnatsd/src/github.com/apcera/gnatsd
    cd $GOPATH
    go build
    go install
    mkdir -p /var/vcap/packages/gnatsd/bin
    mv gnatsd /var/vcap/packages/gnatsd/bin
    cd /var/vcap/packages

mkdir -p /var/vcap/packages/common/

cp -a /home/vcap/cf-release/src/common/* /var/vcap/packages/common/

mkdir -p /var/vcap/packages/syslog_aggregator

cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/

tar -zcvf gnatsd.tar.gz gnatsd common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@gnatsd.tar.gz" http://192.168.201.128:9090/upload/build

rm -fr gnatsd.tar.gz

popd

echo "Gnatsd build success!!"
