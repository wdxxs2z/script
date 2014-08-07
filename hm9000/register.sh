#!/bin/bash

HM9000_CONFIG=/var/vcap/jobs/hm9000/config
HM9000_BIN=/var/vcap/jobs/hm9000/bin
cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

source /home/vcap/script/hm9000/edithm9000.sh

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

if [ ! -d /var/vcap/jobs/hm9000 ]; then
    mkdir -p $HM9000_CONFIG
    mkdir -p $HM9000_BIN 
fi

#--------------------- hm9000 config init... --------------------
pushd $HM9000_CONFIG
cp -a $cfscriptdir/hm9000/config/* $HM9000_CONFIG/
rm -fr $HM9000_CONFIG/hm9000.json

#----- etcdctl init ---------
source /home/vcap/script/hm9000/etcdinit.sh
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl
rm -fr /home/vcap/script/resources/db_url.txt /home/vcap/script/resources/cc_base_url.txt

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

pushd /home/vcap/etcdctl

./build

popd

#nats-urls
rm -fr natsdirs.txt /home/vcap/script/resources/natsip.txt

etcdctl ls /deployment/v1/nats-server/nats_urls >> natsdirs.txt

while read urls
do
etcdctl get $urls >> /home/vcap/script/resources/natsip.txt
done < natsdirs.txt

if [ ! -f /home/vcap/script/resources/natsip.txt ]; then
    echo "nats not deployment...." >> error.txt
    echo "Dea_logging_agent is not success!"
    exit 1
fi

#cc_base_url
etcdctl get /deployment/v1/manifest/domain >> /home/vcap/script/resources/cc_base_url.txt

#etcd_store_urls
rm -fr etcdstoredirs.txt /home/vcap/script/resources/etcd_store_url.txt

etcdctl ls /deployment/v1/manifest/etcdstore >> etcdstoredirs.txt

while read urls
do
etcdctl get $urls >> /home/vcap/script/resources/etcd_store_url.txt
done < etcdstoredirs.txt

if [ ! -f /home/vcap/script/resources/etcd_store_url.txt ]; then
    echo "etcdstores are not deployment...." >> error.txt
    echo "Loggregator is not success!"
    exit 1
fi

#hm9000 url register
etcdctl mkdir /deployment/v1/hm9000/hm9000_urls
rm -fr hm9000_dirs.txt
rm -fr /home/vcap/script/resources/hm9000_urls.txt
flag="true"

etcdctl ls /deployment/v1/hm9000/hm9000_urls >> hm9000_dirs.txt

while read line
do
    etcdctl get $line >> /home/vcap/script/resources/hm9000_urls.txt
done < hm9000_dirs.txt

while read line
do
    if [ "$line" == "$NISE_IP_ADDRESS" ]; then
        flag="flase"
        echo "The ip is exit in loggregator_endpoint : $line"
        break
    fi
done < /home/vcap/script/resources/hm9000_urls.txt

if [ "$flag" == "true" ]; then
    curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/hm9000/hm9000_urls -XPOST -d value=$NISE_IP_ADDRESS
    echo "$NISE_IP_ADDRESS" >> /home/vcap/script/resources/hm9000_urls.txt
fi
#-----------------------------------------------------------------------------
#nats_urls
last=`sed -n '$=' /home/vcap/script/resources/natsip.txt`
i=1
while read line
do
if [ "$i" -eq "$last" ]
then
echo -e "{\"host\":\"$line\",\"port\":4222,\"user\":\"nats\",\"password\":\"c1oudc0w\"}" >> gnats.txt
else
echo -e "{\"host\":\"$line\",\"port\":4222,\"user\":\"nats\",\"password\":\"c1oudc0w\"},\c" >> gnats.txt
let i++
fi
done < /home/vcap/script/resources/natsip.txt

#etcdstore_urls
last=`sed -n '$=' /home/vcap/script/resources/etcd_store_url.txt`
j=1
while read store
do
if [ "$j" -eq "$last" ]
then
echo -e "\"http://$store:4001\"" >> hstores.txt
else
echo -e "\"http://$store:4001\",\c" >> hstores.txt
let j++
fi
done < /home/vcap/script/resources/etcd_store_url.txt

#cc_base_url
base_url=`more /home/vcap/script/resources/cc_base_url.txt`
echo -e "https://api.$base_url.xip.io" >> cctmp.txt

nats_urls=`more gnats.txt`
etcd_store_urls=`more hstores.txt`
cc_base_url=`more cctmp.txt`

edithm9000 "$cc_base_url" "$etcd_store_urls" "$nats_urls"
rm -fr gnats.txt hstores.txt cctmp.txt etcdstoredirs.txt natsdirs.txt hm9000_dirs.txt
popd

echo "HM9000 BIN INIT......"
pushd $HM9000_BIN
cp -a $cfscriptdir/hm9000/bin/* $HM9000_BIN/
chmod -R +x $HM9000_BIN
popd

echo "hm9000 config is already installed success!!"

