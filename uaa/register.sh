#!/bin/bash

echo "**********************************************"
echo "            register uaa                      "
echo "**********************************************"

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

UAA_CONFIG=/var/vcap/jobs/uaa/config
UAA_BIN=/var/vcap/jobs/uaa/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

UAA_REGIST_CONFIG=$cfscriptdir/uaa/config/cf-registrar

indexfile=/home/vcap/script/resources/uaa_index.txt
source /home/vcap/script/uaa/edit_uaa.sh

#------------------------ config ------------------------
if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

if [ ! -d /var/vcap/jobs/uaa ]; then
    mkdir -p $UAA_CONFIG
    mkdir -p $UAA_BIN 
fi

#--------------------------etcd init ----------------------------------
source /home/vcap/script/uaa/etcdinit.sh
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

source /home/vcap/script/uaa/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

rm -fr /home/vcap/script/resources/db_url.txt /home/vcap/script/resources/cc_base_url.txt
rm -fr /home/vcap/script/resources/uaa_urls.txt uaasdirs.txt

etcdctl get /deployment/v1/db >> /home/vcap/script/resources/db_url.txt
etcdctl get /deployment/v1/manifest/domain >> /home/vcap/script/resources/cc_base_url.txt

rm -fr natsdirs.txt /home/vcap/script/resources/natsip.txt

etcdctl mkdir /deployment/v1/nats-server/nats_urls

etcdctl ls /deployment/v1/nats-server/nats_urls >> natsdirs.txt

while read urls
do
etcdctl get $urls >> /home/vcap/script/resources/natsip.txt
done < natsdirs.txt

if [ ! -f /home/vcap/script/resources/natsip.txt ]; then
    echo "nats not deployment...." >> error.txt
    exit 1
fi

etcdctl mkdir /deployment/v1/uaa-server
etcdctl mkdir /deployment/v1/uaa-server/uaa_urls

etcdctl ls /deployment/v1/uaa-server/uaa_urls >> uaasdirs.txt

while read uaaurls
do
etcdctl get $uaaurls >> /home/vcap/script/resources/uaa_urls.txt
done < uaasdirs.txt

# create and register index
etcdctl mkdir /deployment/v1/uaa-server/index
rm -fr uaaindexdirs.txt

# create and register uaa_urls

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/uaa_urls.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/uaa-server/uaa_urls -XPOST -d value=$NISE_IP_ADDRESS
   
        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/uaa-server/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/uaa-server/index/0 $NISE_IP_ADDRESS
            echo "0" > /home/vcap/script/resources/uaa_index.txt
        else
            etcdctl ls /deployment/v1/uaa-server/index/index >> uaaindexdirs.txt
            last=`sed -n '$=' uaaindexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/uaa-server/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > /home/vcap/script/resources/uaa_index.txt
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/uaa-server/index >> oldindex.txt
        for old in `cat oldindex.txt`
        do
            old_urls=`etcdctl get $old`
            if [ "$old_urls" == "$NISE_IP_ADDRESS" ]; then
                echo "$old" |cut -f6 -d '/' > /home/vcap/script/resources/uaa_index.txt
            fi
        done    
    fi
else
    break  
fi

#------------------------- UAA config ---------------------------------
cp -a $cfscriptdir/uaa/config/* $UAA_CONFIG/
rm -fr $UAA_CONFIG/uaa.yml
rm -fr $UAA_CONFIG/cf-registrar/config.yml

pushd $UAA_CONFIG

#localhost
NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

#db_url
db_url=`more /home/vcap/script/resources/db_url.txt`

#nats_urls
while read line
do
echo -e "- nats://nats:c1oudc0w@$line:4222" >> lnats.txt
done < /home/vcap/script/resources/natsip.txt

nats_servers=`more lnats.txt`

#uaa_index
index=$(cat $indexfile)

#base_url
cc_base_url=`more /home/vcap/script/resources/cc_base_url.txt`

edit_uaa "$cc_base_url" "$nats_servers" "$db_url" "$NISE_IP_ADDRESS" "$index"

rm -fr lnats.txt
popd
rm -fr natsdirs.txt oldindex.txt uaasdirs.txt
#--------------------------------- UAA bin ---------------------------------
pushd $UAA_BIN

cp -a $cfscriptdir/uaa/bin/* $UAA_BIN/
chmod +x $UAA_BIN/*

popd

echo "uaa is already installed success!"
