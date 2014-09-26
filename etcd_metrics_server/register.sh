#!/bin/bash

ETCD_METRICS_BIN=/var/vcap/jobs/etcd_metrics_server/bin
export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

cfscriptdir=/home/vcap/cf-dep-configuration
homedir=/home/vcap
indexfile=/home/vcap/script/resources/etcd_metrics_index.txt

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

mkdir -p $ETCD_METRICS_BIN

cp -a $cfscriptdir/etcd_metrics_server/* /var/vcap/jobs/etcd_metrics_server/
cp -a $cfscriptdir/etcd_metrics_server/bin/* $ETCD_METRICS_BIN/
chmod -R +x $ETCD_METRICS_BIN/

#--------------------------etcd init ----------------------------------
source /home/vcap/script/util/etcdinit.sh
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

source /home/vcap/script/util/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

#************************** ETCD_METRICS_BIN **********************
pushd $ETCD_METRICS_BIN
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

last=`sed -n '$=' /home/vcap/script/resources/natsip.txt`
i=1
while read line
do
if [ "$i" -eq "$last" ]
then
echo -e "$line:4222" >> lnats.txt
else
echo -e "$line:4222,\c" >> lnats.txt
let i++
fi
done < /home/vcap/script/resources/natsip.txt

#etcdserver_metrics server and index
etcdctl mkdir /deployment/v1/etcd-metrics-server
etcdctl mkdir /deployment/v1/etcd-metrics-server/metrics_urls
etcdctl mkdir /deployment/v1/etcd-metrics-server/index

rm -fr metricsdirs.txt /home/vcap/script/resources/etcd_metrics_urls.txt

etcdctl ls /deployment/v1/etcd-metrics-server/metrics_urls >> metricsdirs.txt

while read metrics_urls
do
etcdctl get $metrics_urls >> /home/vcap/script/resources/etcd_metrics_urls.txt
done < metricsdirs.txt

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/etcd_metrics_urls.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/etcd-metrics-server/metrics_urls -XPOST -d value=$NISE_IP_ADDRESS

        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/etcd-metrics-server/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/etcd-metrics-server/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr metricsindexdirs.txt
            etcdctl ls /deployment/v1/etcd-metrics-server/index >> metricsindexdirs.txt
            last=`sed -n '$=' metricsindexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/etcd-metrics-server/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/etcd-metrics-server/index >> oldindex.txt
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

nats_urls=`more lnats.txt`
index=$(cat $indexfile)

sed -i "s/192.168.172.136:4222/${nats_urls}/g" `grep 192.168.172.136:4222 -rl $ETCD_METRICS_BIN`
sed -i "s/-index=0/-index=${index}/g" `grep -index=0 -rl $ETCD_METRICS_BIN`

rm ./*.txt
popd
