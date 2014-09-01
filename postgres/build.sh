#!/bin/bash

echo "**********************************************"
echo "            build postgresql                  "
echo "**********************************************"

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

export PATH=/home/vcap/etcdctl/bin:$PATH
source /home/vcap/postgres/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt
rm -fr peers.txt
RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

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

wget http://$RESOURCE_URL/packages/postgres/postgres-9.0.3-1.amd64.tar.gz

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

tar -zxf postgres-9.0.3-1.amd64.tar.gz -C postgres

tar -zcf postgres.tar.gz postgres common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@postgres.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr postgres-9.0.3-1.amd64.tar.gz postgres.tar.gz

popd

echo "Postgresql build ok!"
