#!/bin/bash

cfscriptdir=/home/vcap/cf-dep-configuration
homedir=/home/vcap

CLOUD_CONTROLLER_CLOCK_CONFIG=/var/vcap/jobs/cloud_controller_clock/config
CLOUD_CONTROLLER_CLOCK_BIN=/var/vcap/jobs/cloud_controller_clock/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

source /home/vcap/script/cloud_controller_clock/edit_cc_clock.sh
NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

indexfile=/home/vcap/script/resources/cloud_controller_clock_index.txt

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown -R vcap:vcap /var/vcap
fi

mkdir -p $CLOUD_CONTROLLER_CLOCK_CONFIG
mkdir -p $CLOUD_CONTROLLER_CLOCK_BIN

if [ ! -d $homedir/cf-dep-configuration ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-dep-configuration
    popd
fi

pushd $CLOUD_CONTROLLER_CLOCK_CONFIG
#------------------------- etcd init ---------------------------------------
source /home/vcap/script/cloud_controller_clock/etcdinit.sh
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
etcdctl mkdir /deployment/v1/cloud_controller_clock
etcdctl mkdir /deployment/v1/cloud_controller_clock/ccclock_urls
etcdctl mkdir /deployment/v1/cloud_controller_clock/index

rm -fr ccclockdirs.txt /home/vcap/script/resources/ccclock_urls.txt

etcdctl ls /deployment/v1/cloud_controller_clock/ccclock_urls >> ccclockdirs.txt

while read ccclock_urls
do
etcdctl get $ccclock_urls >> /home/vcap/script/resources/ccclock_urls.txt
done < ccclockdirs.txt

# create and register uaa_urls

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/ccclock_urls.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/cloud_controller_clock/ccclock_urls -XPOST -d value=$NISE_IP_ADDRESS

        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/cloud_controller_clock/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/cloud_controller_clock/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr ccclockindexdirs.txt
            etcdctl ls /deployment/v1/cloud_controller_clock/index >> ccclockindexdirs.txt
            last=`sed -n '$=' ccclockindexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/cloud_controller_clock/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/cloud_controller_clock/index >> oldindex.txt
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

#-------------------------------- Cloud_controller_clock init ----------------
cp -a $cfscriptdir/cloud_controller_clock/config/syslog_forwarder.conf $CLOUD_CONTROLLER_CLOCK_CONFIG
cp -a $cfscriptdir/cloud_controller_clock/config/stacks.yml $CLOUD_CONTROLLER_CLOCK_CONFIG
cp -a $cfscriptdir/cloud_controller_clock/config/newrelic.yml $CLOUD_CONTROLLER_CLOCK_CONFIG
rm -fr $CLOUD_CONTROLLER_CLOCK_CONFIG/cloud_controller_ng.yml

#-------------------------------- Cloud_controller_clock config -------------
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

edit_cc_clock "$NISE_IP_ADDRESS" "$nats_servers" "$index" "$base_url" "$log_endpoint_url" "$db_url"

rm -fr lnats.txt ccclockdirs.txt natsdirs.txt oldindex.txt traffic_dirs.txt loggregatorsdirs.txt

popd

#------------------------------- Cloud_controller_clock bin-------------------
pushd $CLOUD_CONTROLLER_CLOCK_BIN

cp -a $cfscriptdir/cloud_controller_clock/bin/* $CLOUD_CONTROLLER_CLOCK_BIN/
chmod +x $CLOUD_CONTROLLER_CLOCK_BIN/*

popd

echo "Cloud_controller_clock is already installed success!"
