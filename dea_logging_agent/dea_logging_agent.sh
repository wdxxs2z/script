#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/loggregator/bin:$PATH
export GOPATH=/var/vcap/packages/loggregator

LOG_DEA_AGENT_CONFIG=/var/vcap/jobs/dea_logging_agent/config
LOG_DEA_AGENT_BIN=/var/vcap/jobs/dea_logging_agent/bin

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap
indexfile=/home/vcap/script/resources/dea_logging_endpoint_index.txt

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}
loggerator_urls=`more /home/vcap/script/resources/loggerator_url.txt`

source /home/vcap/script/dea_logging_agent/edit_dea_log_agent.sh

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

echo "LOGGREGATOR GIT INIT......"
pushd $homedir/cf-release
cd src/loggregator
git submodule update --init
popd

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

mkdir -p $LOG_DEA_AGENT_CONFIG/
mkdir -p $LOG_DEA_AGENT_BIN/

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages

    echo "Setup git checkout dea_agent......"
    cp -a $homedir/cf-release/src/loggregator /var/vcap/packages
    cd $GOPATH/bin
    ./build-platforms
    ./build
    cd $GOPATH
    echo "--------loggreagator_dea_agent--------"
    mkdir -p /var/vcap/packages/dea_logging_agent
    mv release/deaagent-linux-amd64 /var/vcap/packages/dea_logging_agent/deaagent
    popd

#+++++++++++++++++++++++++++dea_logging_config init+++++++++++++++++++++++++
echo "LOGGREGATOR CONFIG INIT......"
cp -a $cfscriptdir/dea_logging_agent/config/* $LOG_DEA_AGENT_CONFIG
rm -fr $LOG_DEA_AGENT_CONFIG/dea_logging_agent.json

#------------------------- etcd init ---------------------------------------
source /home/vcap/script/dea_logging_agent/etcdinit.sh
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
fic
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

#loggregator server and index
etcdctl mkdir /deployment/v1/dea_logging_agent
etcdctl mkdir /deployment/v1/dea_logging_agent/agent_urls
etcdctl mkdir /deployment/v1/dea_logging_agent/index

rm -fr agentsdirs.txt /home/vcap/script/resources/dea_log_agent_urls.txt

etcdctl ls /deployment/v1/dea_logging_agent/agent_urls >> agentsdirs.txt

while read agent_urls
do
etcdctl get $agent_urls >> /home/vcap/script/resources/dea_log_agent_urls.txt
done < agentsdirs.txt

# create and register uaa_urls

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/dea_log_agent_urls.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/dea_logging_agent/agent_urls -XPOST -d value=$NISE_IP_ADDRESS
        
        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/dea_logging_agent/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/dea_logging_agent/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr deaagentindexdirs.txt
            etcdctl ls /deployment/v1/dea_logging_agent/index >> deaagentindexdirs.txt
            last=`sed -n '$=' deaagentindexdirs.txt`
            new_index=`expr $last + 1`
            etcdctl set /deployment/v1/dea_logging_agent/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/dea_logging_agent/index >> oldindex.txt
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

#deployment
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

logging_endpoint_url=`awk '{a[NR]=$0}END{srand();i=int(rand()*NR+1);print a[i]}' /home/vcap/script/resources/loggregator_endpoint.txt`

index=$(cat $indexfile)

nats_urls=`more lnats.txt`

edit_dea_log_agent "$index" "$logging_endpoint_url" "$nats_urls"

rm -fr lnats.txt

#+++++++++++++++++++++++++++dea_logging_bin init+++++++++++++++++++++++++
echo "Dea_Logging_bin init......"
cp -a $cfscriptdir/dea_logging_agent/bin/* $LOG_DEA_AGENT_BIN/
chmod -R +x $LOG_DEA_AGENT_BIN/