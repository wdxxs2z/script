#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

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


echo "------------Dea_next---------------"
if ! (which ruby); then
    echo "Ruby is not or error setup,please install ruby......"
    exit 1;
fi

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown -R vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "git init dea_ng"
pushd $homedir/cf-release
cd src/dea_next
git submodule update --init
popd


echo "This step will always be install......"
mkdir -p /var/vcap/packages

pushd /var/vcap/packages
#Dea_next main install
cp -a $homedir/cf-release/src/dea_next /var/vcap/packages
cd /var/vcap/packages/dea_next
bundle package --all
bundle install --local --deployment --without development test

#Golang runner dea_dir server 
export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export GOPATH=/var/vcap/packages/dea_next/go
cd /var/vcap/packages/dea_next/go/src/runner
go build
go install runner
mkdir -p /var/vcap/packages/dea_next/go/bin/
cp /var/vcap/packages/dea_next/go/src/runner/runner /var/vcap/packages/dea_next/go/bin/
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

tar -zcf dea_next.tar.gz dea_next common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@dea_next.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr dea_next.tar.gz
popd

echo "Dea next is already installed success!!"