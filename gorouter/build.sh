#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/gorouter/bin:$PATH
export GOPATH=/var/vcap/packages/gorouter

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

export PATH=/home/vcap/etcdctl/bin:$PATH
source /home/vcap/script/util/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt
RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

echo "------------GOROUTER---------------"

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "Setup git checkout gorouter......"
if [ ! -d /var/vcap/packages/gorouter ]; then
    git clone https://github.com/wdxxs2z/cf-router
    mv cf-router /var/vcap/packages/gorouter
fi

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages
    
    cd $GOPATH
    go build
    go install
    mkdir -p bin
    cp -a gorouter $GOPATH/bin/
    popd

pushd /var/vcap/packages

mkdir -p /var/vcap/packages/common/

cp -a /home/vcap/cf-release/src/common/* /var/vcap/packages/common/

mkdir -p /var/vcap/packages/syslog_aggregator

#ubuntu and centos
if grep -q -i ubuntu /etc/issue
then
    cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/
fi

if grep -q -i centos /etc/issue
then
    cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/
    sed -i "s/\/usr\/sbin/\/sbin/g" /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh 
fi

tar -zcf gorouter.tar.gz gorouter common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@gorouter.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr gorouter.tar.gz
popd

echo "Gorouter is already installed success!!"
