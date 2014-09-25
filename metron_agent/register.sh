#!/bin/bash

METRON_AGENT_CONFIG=/var/vcap/jobs/metron_agent/config
METRON_AGENT_BIN=/var/vcap/jobs/metron_agent/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

cfscriptdir=/home/vcap/cf-dep-configuration
homedir=/home/vcap
source /home/vcap/script/metron_agent/editmetron.sh
indexfile=/home/vcap/script/resources/metron_agent_index.txt

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-dep-configuration ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-dep-configuration
    popd
fi

mkdir -p $METRON_AGENT_CONFIG
mkdir -p $METRON_AGENT_BIN

pushd $METRON_AGENT_CONFIG

cp -a $cfscriptdir/metron_agent/config/* $METRON_AGENT_CONFIG/
rm -fr $METRON_AGENT_CONFIG/metron_agent.json

source /home/vcap/script/util/etcdinit.sh
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

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

#zones
rm -fr /home/vcap/script/resources/cc_zone.txt
rm -fr zonedirs.txt
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

#etcd_store_urls
rm -fr etcdstoredirs.txt /home/vcap/script/resources/etcd_store_url.txt

etcdctl ls /deployment/v1/manifest/etcdstore >> etcdstoredirs.txt

while read urls
do
etcdctl get $urls >> /home/vcap/script/resources/etcd_store_url.txt
done < etcdstoredirs.txt

if [ ! -f /home/vcap/script/resources/etcd_store_url.txt ]; then
    echo "etcdstores are not deployment...." >> error.txt
    echo "Loggregator_traffic is not success!"
    exit 1
fi

#----------------------- etcd_urls ------------------------------------
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

#Metron_agent url register
etcdctl mkdir /deployment/v1/metron_agent/metron_agent_url
etcdctl mkdir /deployment/v1/metron_agent/index

rm -fr metron_agentdirs.txt /home/vcap/script/resources/metron_agent_urls.txt

etcdctl ls /deployment/v1/metron_agent/metron_agent_url >> metron_agentdirs.txt

while read metron_agent_url
do
etcdctl get $metron_agent_url >> /home/vcap/script/resources/metron_agent_urls.txt
done < metron_agentdirs.txt

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/metron_agent_urls.txt`
    do
    if [ "$NISE_IP_ADDRESS" == "$j" ]
    then
        echo "the ip:$NISE_IP_ADDRESS is exits!"
        flag="true"
    fi
    done
    if [ "$flag" == "false" ]
    then
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/metron_agent/metron_agent_url -XPOST -d value=$NISE_IP_ADDRESS

        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/metron_agent/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/metron_agent/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr metron_agent_indexdirs.txt
            etcdctl ls /deployment/v1/metron_agent/index >> metron_agent_indexdirs.txt
            last=`sed -n '$=' metron_agent_indexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/metron_agent/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/metron_agent/index >> oldindex.txt
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

#zone target and register to metron pool
zone=`awk '{a[NR]=$0}END{srand();i=int(rand()*NR+1);print a[i]}' /home/vcap/script/resources/cc_zone.txt`
if [ ! -d /home/vcap/script/resources/zones ]; then
mkdir -p /home/vcap/script/resources/zones
fi

if [ ! -f /home/vcap/script/resources/zones/$zone.txt ]; then
touch /home/vcap/script/resources/zones/$zone.txt
fi

zonename=`cat /home/vcap/script/resources/zones/$zone.txt`
etcdctl mkdir /deployment/v1/metron_agent/pool/$zone
zonetarget="true"
rm -rf z0dir.txt z1dir.txt

#if the radom zone name is already register,
etcdctl ls /deployment/v1/metron_agent/pool >> z0dir.txt
while read line
do 
    zonen=`etcdctl get $line`
    if [ "$zonen" == "$zone" ]; then
        zonetarget="false"
        break
    fi
done < z0dir.txt

etcdctl ls /deployment/v1/metron_agent/pool/$zone >> z1dir.txt
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
curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/metron_agent/pool/$zone -XPOST -d value=$NISE_IP_ADDRESS
fi

nats_ip=`more ltnats.txt`
index=$(cat $indexfile)
etcd_urls=`more lstores.txt`

editmetron "$etcd_urls" "$index" "$nats_ip" "$zone"

rm ./*.txt

popd

#++++++++++++++++++++++ Metron Agent Bin ++++++++++++++++++++++++++++++++
cp -a $cfscriptdir/metron_agent/bin/* $METRON_AGENT_BIN/
chmod -R +x $METRON_AGENT_BIN/