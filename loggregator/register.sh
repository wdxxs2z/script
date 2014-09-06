#!/bin/bash

LOGGREGATOR_CONFIG=/var/vcap/jobs/loggregator/config
LOGGREGATOR_BIN=/var/vcap/jobs/loggregator/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap
indexfile=/home/vcap/script/resources/loggregator_index.txt

source /home/vcap/script/util/editlog.sh

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

if [ ! -d /var/vcap/jobs/loggregator ]; then
    mkdir -p $LOGGREGATOR_CONFIG
    mkdir -p $LOGGREGATOR_BIN 
fi

#check cc_url number and already created loggregator number,if cc_url>loggerator,can create,otherwise can't create loggerator.

echo "LOGGREGATOR CONFIG INIT......"
if [ ! -d $LOGGREGATOR_CONFIG ]; then
mkdir -p $LOGGREGATOR_CONFIG
fi
pushd $LOGGREGATOR_CONFIG

cp -a $cfscriptdir/loggregator/config/* $LOGGREGATOR_CONFIG/
rm -fr $LOGGREGATOR_CONFIG/loggregator.json

#--------------------------etcd init ----------------------------------
source /home/vcap/script/loggregator/etcdinit.sh
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

register_nats_urls=/deployment/v1/nats-server/nats_urls
register_uaa_urls=/deployment/v1/uaa-server

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

pushd /home/vcap/etcdctl

./build

popd

source /home/vcap/script/cloud_controller_clock/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

rm -fr /home/vcap/script/resources/db_url.txt /home/vcap/script/resources/cc_base_url.txt
rm -fr /home/vcap/script/resources/loggregator_urls.txt loggregatorsdirs.txt

#db_url
etcdctl get /deployment/v1/db >> /home/vcap/script/resources/db_url.txt

#cc_base_url
etcdctl get /deployment/v1/manifest/domain >> /home/vcap/script/resources/cc_base_url.txt

#nats-urls
rm -fr natsdirs.txt /home/vcap/script/resources/natsip.txt

etcdctl ls /deployment/v1/nats-server/nats_urls >> natsdirs.txt

while read urls
do
etcdctl get $urls >> /home/vcap/script/resources/natsip.txt
done < natsdirs.txt

if [ ! -f /home/vcap/script/resources/natsip.txt ]; then
    echo "nats not deployment...." >> error.txt
    echo "Loggregator is not success!"
    exit 1
fi

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

# zones create and register
rm -fr /home/vcap/script/resources/cc_zone.txt
etcdctl ls /deployment/v1/manifest/zone >> zonedirs.txt

while read zone_targets
do
etcdctl get $zone_targets >> /home/vcap/script/resources/cc_zone.txt
done < zonedirs.txt

if [ ! -f /home/vcap/script/resources/cc_zone.txt ]; then
    echo "zones not set...." >> error.txt
    echo "Loggregator is not success!"
    exit 1
fi

#loggregator server and index
etcdctl mkdir /deployment/v1/loggregator-server
etcdctl mkdir /deployment/v1/loggregator-server/loggregator_urls
etcdctl mkdir /deployment/v1/loggregator-server/index

rm -fr loggregatorsdirs.txt /home/vcap/script/resources/loggregator_urls.txt

etcdctl ls /deployment/v1/loggregator-server/loggregator_urls >> loggregatorsdirs.txt

while read loggregator_urls
do
etcdctl get $loggregator_urls >> /home/vcap/script/resources/loggregator_urls.txt
done < loggregatorsdirs.txt

# create and register uaa_urls

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/loggregator_urls.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/loggregator-server/loggregator_urls -XPOST -d value=$NISE_IP_ADDRESS

        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/loggregator-server/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/loggregator-server/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr loggregatorindexdirs.txt
            etcdctl ls /deployment/v1/loggregator-server/index >> loggregatorindexdirs.txt
            last=`sed -n '$=' loggregatorindexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/loggregator-server/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/loggregator-server/index >> oldindex.txt
        for old in `cat oldindex.txt`
        do
            old_urls=`etcdctl get $old`
            if [ "$old_urls" == "$NISE_IP_ADDRESS" ]; then
                echo "$old" |cut -f6 -d '/' > $indexfile
            fi
        done       
    fi
else
    break  
fi

# *************************************************************************
cc_base_url=`more /home/vcap/script/resources/cc_base_url.txt`
etcd_sotre_url=`more /home/vcap/script/resources/etcd_store_url.txt`

last=`sed -n '$=' /home/vcap/script/resources/etcd_store_url.txt`
j=1
while read store
do
if [ "$j" -eq "$last" ]
then
echo -e "\"http://$store:4001\"" >> lstores.txt
else
echo -e "\"http://$store:4001\",\c" >> lstores.txt
let j++
fi
done < /home/vcap/script/resources/etcd_store_url.txt

last=`sed -n '$=' /home/vcap/script/resources/natsip.txt`
i=1
while read line
do
if [ "$i" -eq "$last" ]
then
echo -e "\"$line\"" >> lnats.txt
else
echo -e "\"$line\",\c" >> lnats.txt
let i++
fi
done < /home/vcap/script/resources/natsip.txt

#index if empty,put the index:0,or get the index from the file,and add 1.
index=$(cat $indexfile)

etcd_urls=`more lstores.txt`
nats_urls=`more lnats.txt`

editlog "$etcd_urls" "$nats_urls" "$index"

rm -fr lstores.txt lnats.txt
#--------------------------radom save to zones floder -> zname.txt  ----------------------------
zone=`awk '{a[NR]=$0}END{srand();i=int(rand()*NR+1);print a[i]}' /home/vcap/script/resources/cc_zone.txt`
if [ ! -d /home/vcap/script/resources/zones ]; then
mkdir -p /home/vcap/script/resources/zones
fi

if [ ! -f /home/vcap/script/resources/zones/$zone.txt ]; then
touch /home/vcap/script/resources/zones/$zone.txt
fi

zonename=`cat /home/vcap/script/resources/zones/$zone.txt`
etcdctl mkdir /deployment/v1/loggregator-server/pool/$zone
zonetarget="true"
rm -rf z0dir.txt z1dir.txt

#if the radom zone name is already register,
etcdctl ls /deployment/v1/loggregator-server/pool >> z0dir.txt
while read line
do 
    zonen=`etcdctl get $line`
    if [ "$zonen" == "$zone" ]; then
        zonetarget="false"
        break
    fi
done < z0dir.txt

etcdctl ls /deployment/v1/loggregator-server/pool/$zone >> z1dir.txt
while read line
do
    zoneip=`etcdctl get $line`
    if [ "$zoneip" == "$NISE_IP_ADDRESS" ]; then
        zonetarget="false"
        break
    fi
done < z1dir.txt

echo $NISE_IP_ADDRESS |grep -q "$zonename"
if [ $? -eq 0 ] && [[ $(stat -c %s /home/vcap/script/resources/zones/$zone.txt) -ne 0 ]] && [ "$zonetarget" == "false" ]
then
    echo "include the ip......or this file is empty! zone or zoneip is already exits"
else
echo $NISE_IP_ADDRESS >> /home/vcap/script/resources/zones/$zone.txt
curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/loggregator-server/pool/$zone -XPOST -d value=$NISE_IP_ADDRESS
fi

rm -fr etcdstoredirs.txt loggregatorsdirs.txt natsdirs.txt z0dir.txt z1dir.txt zonedirs.txt oldindex.txt

popd

#+++++++++++++++++++++++++Loggregator BIN+++++++++++++++++++++++++++++++++++++++++++++++++++++
echo "Loggregator bin init......"
cp -a $cfscriptdir/loggregator/bin/* $LOGGREGATOR_BIN/
chmod -R +x $LOGGREGATOR_BIN/
