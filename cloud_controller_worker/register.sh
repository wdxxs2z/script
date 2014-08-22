#!/bin/bash

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

CLOUD_CONTROLLER_WORKER_CONFIG=/var/vcap/jobs/cloud_controller_worker/config
CLOUD_CONTROLLER_WORKER_BIN=/var/vcap/jobs/cloud_controller_worker/bin

source /home/vcap/script/cloud_controller_worker/edit_cc_worker.sh
NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

indexfile=/home/vcap/script/resources/cloud_controller_worker_index.txt

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
fi

mkdir -p $CLOUD_CONTROLLER_WORKER_CONFIG
mkdir -p $CLOUD_CONTROLLER_WORKER_BIN

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

pushd $CLOUD_CONTROLLER_WORKER_CONFIG
#------------------------- etcd init ---------------------------------------
source /home/vcap/script/cloud_controller_worker/etcdinit.sh
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

#loggregator_endpoint_urls
rm -rf /home/vcap/script/resources/loggregator_endpoint.txt
rm -fr traffic_dirs.txt

etcdctl ls /deployment/v1/loggregator-traffic/traffic_url >> traffic_dirs.txt

while read line
do
    etcdctl get $line >> /home/vcap/script/resources/loggregator_endpoint.txt
done < traffic_dirs.txt

if [ ! -f /home/vcap/script/resources/loggregator_endpoint.txt ]; then
    echo "loggregator_traffic not deployment...." >> error.txt
    echo "Dea_logging_agent is not success!"
    exit 1
fi

#db
etcdctl get /deployment/v1/db >> /home/vcap/script/resources/db_url.txt

#cc_base_url
etcdctl get /deployment/v1/manifest/domain >> /home/vcap/script/resources/cc_base_url.txt

#index and register
etcdctl mkdir /deployment/v1/cloud_controller_worker
etcdctl mkdir /deployment/v1/cloud_controller_worker/ccworker_urls
etcdctl mkdir /deployment/v1/cloud_controller_worker/index

rm -fr ccworkerdirs.txt /home/vcap/script/resources/ccworker_urls.txt

etcdctl ls /deployment/v1/cloud_controller_worker/ccworker_urls >> ccworkerdirs.txt

while read ccworker_urls
do
etcdctl get $ccworker_urls >> /home/vcap/script/resources/ccworker_urls.txt
done < ccworkerdirs.txt

# create and register uaa_urls

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/ccworker_urls.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/cloud_controller_worker/ccworker_urls -XPOST -d value=$NISE_IP_ADDRESS

        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/cloud_controller_worker/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/cloud_controller_worker/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr ccworkerindexdirs.txt
            etcdctl ls /deployment/v1/cloud_controller_worker/index >> ccworkerindexdirs.txt
            last=`sed -n '$=' ccworkerindexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/cloud_controller_worker/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/cloud_controller_worker/index >> oldindex.txt
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
#--------------------------- cloud_controller_worker config -----------------------------------
cp -a $cfscriptdir/cloud_controller_worker/config/idmapd.conf $CLOUD_CONTROLLER_WORKER_CONFIG
cp -a $cfscriptdir/cloud_controller_worker/config/newrelic.yml $CLOUD_CONTROLLER_WORKER_CONFIG
cp -a $cfscriptdir/cloud_controller_worker/config/nfs-common $CLOUD_CONTROLLER_WORKER_CONFIG
cp -a $cfscriptdir/cloud_controller_worker/config/stacks.yml $CLOUD_CONTROLLER_WORKER_CONFIG
cp -a $cfscriptdir/cloud_controller_worker/config/syslog_forwarder.conf $CLOUD_CONTROLLER_WORKER_CONFIG

if [ -f $$CLOUD_CONTROLLER_WORKER_CONFIG/cloud_controller_ng.yml ]; then
    rm -fr $CLOUD_CONTROLLER_WORKER_CONFIG/cloud_controller_ng.yml
fi

rm -fr $CLOUD_CONTROLLER_WORKER_CONFIG/cloud_controller_ng.yml

#----------------------------- cloud_controller_worker--------------------------
#nats-servers

while read line
do
echo -e "- nats://nats:c1oudc0w@$line:4222" >> lnats.txt
done < /home/vcap/script/resources/natsip.txt

nats_servers=`more lnats.txt`

#index
index=$(cat $indexfile)

#base_url
base_url=`more /home/vcap/script/resources/cc_base_url.txt`

#log_endpoint_url random !!!!
log_endpoint_url=`awk '{a[NR]=$0}END{srand();i=int(rand()*NR+1);print a[i]}' /home/vcap/script/resources/loggregator_endpoint.txt`

#db_url
db_url=`more /home/vcap/script/resources/db_url.txt`

edit_cc_worker "$NISE_IP_ADDRESS" "$nats_servers" "$index" "$base_url" "$log_endpoint_url" "$db_url"

rm -fr lnats.txt ccworkerdirs.txt natsdirs.txt oldindex.txt traffic_dirs.txt

popd

#----------------------------- cloud_controller_worker_bin------------
pushd $CLOUD_CONTROLLER_WORKER_BIN

cp -a $cfscriptdir/cloud_controller_worker/bin/* $CLOUD_CONTROLLER_WORKER_BIN/
chmod -R +x $CLOUD_CONTROLLER_WORKER_BIN/ 

popd

echo "cloud_controller_worker is already installed success!"
