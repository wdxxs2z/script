#!/bin/bash

echo "**********************************************"
echo "            build gnatsd                      "
echo "**********************************************"

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

echo "GNATSD GIT INIT......"
pushd $homedir/cf-release
cd src/gnatsd
git submodule update --init
popd

#----------------- build install ------------------------
echo "This step will always be install......"
mkdir -p /var/vcap/packages

pushd /var/vcap/packages

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/gnatsd/bin:$PATH
export GOPATH=/var/vcap/packages/gnatsd

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

tar -zcf gnatsd.tar.gz gnatsd common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@gnatsd.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr gnatsd.tar.gz

popd

echo "Gnatsd build success!!"