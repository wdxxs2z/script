#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH
export DEA_NEXT_GEMFILE=/var/vcap/packages/dea_next/Gemfile

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/dea_next/go/bin:$PATH
export GOPATH=/var/vcap/packages/dea_next/go

DEA_NEXT_CONFIG=/var/vcap/jobs/dea_next/config
DEA_NEXT_BIN=/var/vcap/jobs/dea_next/bin
cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

source /home/vcap/script/dea_next/editdea_ng.sh
NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

indexfile=/home/vcap/script/resources/dea_next_index.txt

echo "------------Dea_next---------------"

if ! (which ruby); then
    echo "Ruby is not or error setup,please install ruby......"
    exit 1;
fi

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown -R vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    pushd $homedir
    git clone https://github.com/cloudfoundry/cf-release 
    cd $homedir/cf-release
    git checkout c4dfff2
    git submodule update --init
    popd
fi

echo "git init dea_ng"
pushd $homedir/cf-release
cd src/dea_next
git checkout cf84d0922c
git submodule update --init
popd

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

mkdir -p /var/vcap/jobs/dea_next/bin
mkdir -p /var/vcap/jobs/dea_next/config

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages

    echo "Setup git checkout dea_next......"
    cp -a $homedir/cf-release/src/dea_next /var/vcap/packages
    cd /var/vcap/packages/dea_next
    bundle install

    echo "Set install golang file dirserver"
    cd /var/vcap/packages/dea_next/go/src/runner
    go build
    go install
    popd


pushd $DEA_NEXT_CONFIG
cp -a $cfscriptdir/dea_next/config/syslog_forwarder.conf $DEA_NEXT_CONFIG
rm -fr $DEA_NEXT_CONFIG/dea.yml

#------------------------- etcd init ---------------------------------------
source /home/vcap/script/dea_next/etcdinit.sh
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl
rm -fr /home/vcap/script/resources/cc_base_url.txt

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

#cc_base_url
rm -fr /home/vcap/script/resources/cc_base_url.txt
etcdctl get /deployment/v1/manifest/domain >> /home/vcap/script/resources/cc_base_url.txt

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

# create and register dea_next_urls
etcdctl mkdir /deployment/v1/dea_next
etcdctl mkdir /deployment/v1/dea_next/dea_next_urls
etcdctl mkdir /deployment/v1/dea_next/index

rm -fr dea_nextdirs.txt /home/vcap/script/resources/dea_next_urls.txt

etcdctl ls /deployment/v1/dea_next/dea_next_urls >> dea_nextdirs.txt

while read dea_next_urls
do
etcdctl get $dea_next_urls >> /home/vcap/script/resources/dea_next_urls.txt
done < dea_nextdirs.txt

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/dea_next_urls.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/dea_next/dea_next_urls -XPOST -d value=$NISE_IP_ADDRESS

        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/dea_next/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/dea_next/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr dea_nextindexdirs.txt
            etcdctl ls /deployment/v1/dea_next/index >> dea_nextindexdirs.txt
            last=`sed -n '$=' dea_nextindexdirs.txt`
            new_index=`expr $last + 1`
            etcdctl set /deployment/v1/dea_next/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/dea_next/index >> oldindex.txt
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

#---------------- dea_ng config function install... ------------
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

#zone
zone=`awk '{a[NR]=$0}END{srand();i=int(rand()*NR+1);print a[i]}' /home/vcap/script/resources/cc_zone.txt`

editdea_ng "$nats_servers" "$base_url" "$log_endpoint_url" "$index" "$zone"

rm -fr lnats.txt dea_nextdirs.txt natsdirs.txt oldindex.txt traffic_dirs.txt zonedirs.txt

popd

#------------------- dea_next bin init -------------------------
echo "Dea_next bin sh will be copy......"
pushd $DEA_NEXT_BIN

cp -a $cfscriptdir/dea_next/bin/dea_ctl $DEA_NEXT_BIN/
cp -a $cfscriptdir/dea_next/bin/dir_server_ctl $DEA_NEXT_BIN/
chmod -R +x $DEA_NEXT_BIN/

popd

echo "DEA_NEXT IS ALREADY INSTALLED."
