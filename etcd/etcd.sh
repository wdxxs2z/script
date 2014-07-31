#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/etcd/bin:$PATH
export GOPATH=/var/vcap/packages/etcd

ETCD_CONFIG=/var/vcap/jobs/etcd/config
ETCD_BIN=/var/vcap/jobs/etcd/bin
cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}
etcdips=`more /home/vcap/script/resources/etcd_store_url.txt`

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

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

if [ ! -d $ETCD_CONFIG ]; then
    mkdir -p $ETCD_CONFIG
fi

if [ ! -d $ETCD_BIN ]; then
    mkdir -p $ETCD_BIN
fi

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages

    echo "Setup git checkout etcd......"
    cp -a $homedir/cf-release/src/etcd /var/vcap/packages
    cd /var/vcap/packages/etcd
    ./build

    popd

echo "ETCD CONFIG will be copy......"
pushd $ETCD_CONFIG
cp -a $cfscriptdir/etcd/config/syslog_forwarder.conf $ETCD_CONFIG

#Jedgement the etcd_store_url.txt if not exit,add it in the file
echo $NISE_IP_ADDRESS |grep -q "$etcdips"
if [ $? -eq 0 ] && [[ $(stat -c %s /home/vcap/script/resources/etcd_store_url.txt) -ne 0 ]]
then
    echo "Include......or the file is empty!"
else
    echo "$NISE_IP_ADDRESS" >> /home/vcap/script/resources/etcd_store_url.txt
fi

popd

echo "ETCD BIN will be copy......."
pushd $ETCD_BIN
cp -a $cfscriptdir/etcd/bin/etcd_ctl $ETCD_BIN
chmod -R +x $ETCD_BIN/ 
popd

echo "ETCD INSTALL OK!"
