#!/bin/bash

GOROUTER_CONFIG=/var/vcap/jobs/gorouter/config
GOROUTER_BIN=/var/vcap/jobs/gorouter/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap
indexfile=/home/vcap/script/resources/router_index.txt

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

source /home/vcap/script/gorouter/editgorouter.sh

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

mkdir -p $GOROUTER_CONFIG
mkdir -p $GOROUTER_BIN

#-------------------- gorouter config init... ---------------------
pushd $GOROUTER_CONFIG
cp -a $cfscriptdir/gorouter/config/* $GOROUTER_CONFIG/
rm -fr $GOROUTER_CONFIG/gorouter.yml

#----- etcdctl init ---------
source /home/vcap/script/gorouter/etcdinit.sh
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

source /home/vcap/script/gorouter/etcdinit.sh > peers.txt
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
    echo "gorouter is not success!"
    exit 1
fi

#log_endpoint_url random !!!!
rm -rf /home/vcap/script/resources/loggregator_endpoint.txt
rm -fr traffic_dirs.txt
etcdctl ls /deployment/v1/loggregator-traffic/traffic_url >> traffic_dirs.txt

while read line
do
    etcdctl get $line >> /home/vcap/script/resources/loggregator_endpoint.txt
done < traffic_dirs.txt

if [ ! -f /home/vcap/script/resources/loggregator_endpoint.txt ]; then
    echo "loggregator_traffic not deployment...." >> error.txt
    echo "gorouter is not success!"
    exit 1
fi

#index and register gorouter urls
etcdctl mkdir /deployment/v1/gorouter
etcdctl mkdir /deployment/v1/gorouter/router
etcdctl mkdir /deployment/v1/gorouter/index

rm -fr routersdirs.txt /home/vcap/script/resources/router.txt

etcdctl ls /deployment/v1/gorouter/router >> routersdirs.txt

while read router_urls
do
etcdctl get $router_urls >> /home/vcap/script/resources/router.txt
done < routersdirs.txt


flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/router.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/gorouter/router -XPOST -d value=$NISE_IP_ADDRESS
        
        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/gorouter/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/gorouter/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr gorouterindexdirs.txt
            etcdctl ls /deployment/v1/gorouter/index >> gorouterindexdirs.txt
            last=`sed -n '$=' gorouterindexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/gorouter/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/gorouter/index >> oldindex.txt
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

#nats_urls
while read line
do 
echo -e "  - host: "$line"\n""    port: 4222""\n""    user: nats""\n""    pass: \"c1oudc0w\"""\n" >> gnats.txt
done < /home/vcap/script/resources/natsip.txt

nats=`more gnats.txt`

#index
index=$(cat $indexfile)

#loggregator_endpoint
log_endpoint_url=`awk '{a[NR]=$0}END{srand();i=int(rand()*NR+1);print a[i]}' /home/vcap/script/resources/loggregator_endpoint.txt`


editgorouter "$nats" "$log_endpoint_url" "$index"

rm -fr gnats.txt oldindex.txt gorouterindexdirs.txt routersdirs.txt natsdirs.txt traffic_dirs.txt

popd

echo "GOROUTER BIN INIT......"
pushd $GOROUTER_BIN
cp -a $cfscriptdir/gorouter/bin/* $GOROUTER_BIN/
chmod -R +x $GOROUTER_BIN/
popd

echo "gorouter config is already registed success!!"
