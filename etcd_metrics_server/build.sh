#!/bin/bash

homedir=/home/vcap

export PATH=/home/vcap/etcdctl/bin:$PATH
source /home/vcap/script/util/etcdinit.sh > peers.txt
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
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "GOROUTER GIT INIT......"
pushd $homedir/cf-release
cd src/etcd-metrics-server
git submodule update --init
popd

mkdir -p /var/vcap/packages
pushd /var/vcap/packages

cd /home/vcap/cf-release/src
mkdir -p /var/vcap/packages/etcd-metrics-server/bin

REPO_NAME=github.com/cloudfoundry-incubator/etcd-metrics-server
REPO_DIR=/var/vcap/packages/etcd-metrics-server/src/${REPO_NAME}

mkdir -p $(dirname $REPO_DIR)

cp -a /home/vcap/cf-release/src/etcd-metrics-server/ $REPO_DIR

export GOROOT=$(readlink -nf /home/vcap/go)
export GOPATH=/var/vcap/packages/etcd-metrics-server:${REPO_DIR}/Godeps/_workspace
export PATH=$GOROOT/bin:$PATH

go install ${REPO_NAME}
cp /home/vcap/go/bin/etcd-metrics-server /var/vcap/packages/etcd-metrics-server/bin/
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

tar -zcf etcd-metrics-server.tar.gz etcd-metrics-server common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@etcd-metrics-server.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr etcd-metrics-server.tar.gz

popd
