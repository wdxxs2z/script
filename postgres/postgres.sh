#!/bin/bash

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

POSTGRES_CONFIG=/var/vcap/jobs/postgres/config
POSTGRES_BIN=/var/vcap/jobs/postgres/bin
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
#----------------- git init --------------------------
if [ ! -d $homedir/cf-release ]; then
    pushd $homedir
    git clone https://github.com/cloudfoundry/cf-release
    cd $homedir/cf-release
    git checkout c4dfff2
    git submodule update --init
    popd
fi


if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

    mkdir -p $POSTGRES_CONFIG
    mkdir -p $POSTGRES_BIN

#----------------- postgresql init ---------------------
if [ ! -d /var/vcap/packages/postgres ]; then
    mkdir -p /var/vcap/packages/postgres
fi

pushd /var/vcap/packages

wget http://blob.cfblob.com/rest/objects/4e4e78bca31e122004e4e8ec646e2104f306af917d30
mv 4e4e78bca31e122004e4e8ec646e2104f306af917d30 postgres/postgres-9.0.3-1.amd64.tar.gz

tar xzf postgres/postgres-9.0.3-1.amd64.tar.gz -C postgres

popd

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
