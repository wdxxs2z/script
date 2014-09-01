#!/bin/bash

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

POSTGRES_CONFIG=/var/vcap/jobs/postgres/config
POSTGRES_BIN=/var/vcap/jobs/postgres/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

register_db_dir=/deployment/v1/db

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
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

source /home/vcap/script/postgres/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

mkdir -p $POSTGRES_CONFIG
mkdir -p $POSTGRES_BIN

#---------------- postgres config ----------------------
if [ ! -d /var/vcap/jobs/postgres ]; then
    mkdir -p /var/vcap/jobs/postgres
fi

pushd $POSTGRES_CONFIG

rm -fr postgresql.conf pg_hba.conf

cp -a $cfscriptdir/postgres/config/* $POSTGRES_CONFIG/

popd

#--------------- postgres bin --------------------------
if [ ! -d $POSTGRES_BIN ]; then
    mkdir -p $POSTGRES_BIN
fi

pushd $POSTGRES_BIN

cp -a $cfscriptdir/postgres/bin/* $POSTGRES_BIN/
chmod +x $POSTGRES_BIN/postgres_ctl

popd

#--------------- postgresql register -------------------
etcdctl set $register_db_dir $NISE_IP_ADDRESS

echo "Postgresql is already installed success!"
