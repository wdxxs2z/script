#!/bin/bash

echo "**********************************************"
echo "            register gnatsd                   "
echo "**********************************************"

GNATSD_CONFIG=/var/vcap/jobs/nats/config
GNATSD_BIN=/var/vcap/jobs/nats/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}
natsips=`more /home/vcap/script/resources/natsip.txt`

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

mkdir -p $GNATSD_CONFIG
mkdir -p $GNATSD_BIN

#--------------------- etcd init --------------------------
source /home/vcap/script/gnatsd/etcdinit.sh
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

register_nats_dir=/deployment/v1/nats-server

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

pushd /home/vcap/etcdctl

./build

popd

source /home/vcap/script/util/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

#--------------------- etcd register ----------------------
etcdctl mkdir $register_nats_dir
etcdctl mkdir $register_nats_dir/index
#--------------------- etcd register ip --------------------
rm -fr natsdirs.txt natsurls.txt natsindexdirs.txt

etcdctl mkdir $register_nats_dir/nats_urls

etcdctl ls $register_nats_dir/nats_urls >> natsdirs.txt

while read urls
do
etcdctl get $urls >> natsurls.txt
done < natsdirs.txt

if [ ! -f natsurls.txt ]; then
    touch natsurls.txt
fi

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat natsurls.txt`
    do
    if [ "$NISE_IP_ADDRESS" == "$j" ]
    then
        echo "the ip:$NISE_IP_ADDRESS is exits!"
        flag="true"
    fi
    done
    if [ "$flag" == "false" ]
    then
        echo $etcd_endpoint
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/nats-server/nats_urls -XPOST -d value=$NISE_IP_ADDRESS
        
        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/$register_nats_dir/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set $register_nats_dir/index/0 $NISE_IP_ADDRESS
            echo "0" > /home/vcap/script/resources/gnatsd_index.txt
        else
            etcdctl ls $register_nats_dir/index >> natsindexdirs.txt
            last=`sed -n '$=' natsindexdirs.txt`
            new_index=$last
            etcdctl set $register_nats_dir/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > /home/vcap/script/resources/gnatsd_index.txt
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
    fi
else
    break  
fi

rm -fr natsdirs.txt natsurls.txt

pushd $GNATSD_CONFIG
cp -a $cfscriptdir/nats/config/* $GNATSD_CONFIG
sed -i "s/192.168.64.142/${NISE_IP_ADDRESS}/g" `grep 192.168.64.142 -rl $GNATSD_CONFIG`

#Jedgement the natsip.txt if not exit,add it in the file
echo $NISE_IP_ADDRESS |grep -q "$natsips"
if [ $? -eq 0 ] && [[ $(stat -c %s /home/vcap/script/resources/natsip.txt) -ne 0 ]]
then
    echo "Include......or the file is empty!"
else
    echo "$NISE_IP_ADDRESS" >> /home/vcap/script/resources/natsip.txt
fi

popd

echo "GONATSD BIN INIT......"
cp -a $cfscriptdir/nats/bin/* $GNATSD_BIN
chmod -R +x $GNATSD_BIN/*
