#!/bin/bash

LOG_TRAFFICCONTROLLER_CONFIG=/var/vcap/jobs/loggregator_trafficcontroller/config
LOG_TRAFFICCONTROLLER_BIN=/var/vcap/jobs/loggregator_trafficcontroller/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap
indexfile=/home/vcap/script/resources/ltraffic_index.txt

source /home/vcap/script/loggregator_trafficcontroller/editlogtraffic.sh

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

mkdir -p $LOG_TRAFFICCONTROLLER_CONFIG
mkdir -p $LOG_TRAFFICCONTROLLER_BIN

echo "LOGGREGATOR CONFIG INIT......"
if [ ! -d $LOG_TRAFFICCONTROLLER_CONFIG ]; then
mkdir -p $LOG_TRAFFICCONTROLLER_CONFIG
fi
pushd $LOG_TRAFFICCONTROLLER_CONFIG

cp -a $cfscriptdir/loggregator_trafficcontroller/config/* $LOG_TRAFFICCONTROLLER_CONFIG/
rm -fr $LOG_TRAFFICCONTROLLER_CONFIG/loggregator_trafficcontroller.json

loggerator_urls=`more /home/vcap/script/resources/loggregator_url.txt`
log_endpoing_url=`more /home/vcap/script/resources/loggregator_endpoint.txt`
#zone_num="0"

#---------------- etcd init --------------------
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

source /home/vcap/script/loggregator_trafficcontroller/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

rm -fr /home/vcap/script/resources/db_url.txt /home/vcap/script/resources/cc_base_url.txt
rm -fr /home/vcap/script/resources/loggregator_url.txt loggregatorsdirs.txt

#cc_base_url
etcdctl get /deployment/v1/manifest/domain >> /home/vcap/script/resources/cc_base_url.txt
cc_base_url=`more /home/vcap/script/resources/cc_base_url.txt`

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

#loggerator_urls
rm -fr /home/vcap/script/resources/loggerator_url.txt
rm -fr loggregator_dirs.txt

etcdctl ls /deployment/v1/loggregator-server/loggregator_urls >> loggregator_dirs.txt

while read line
do
    etcdctl get $line >> /home/vcap/script/resources/loggregator_url.txt
done < loggregator_dirs.txt

if [ ! -f /home/vcap/script/resources/loggregator_url.txt ]; then
    echo "loggregator_server is not set..." >> error.txt
    echo "Loggregator_trafficcontroller is not success!"
    exit 1
fi

#loggerator_urls 2 zone
rm -fr /home/vcap/script/resources/zones
rm -fr zonen.txt zonelogser.txt

etcdctl ls /deployment/v1/loggregator-server/pool |cut -f6 -d '/' >> zonen.txt

mkdir /home/vcap/script/resources/zones

while read line
do
    touch /home/vcap/script/resources/zones/$line.txt
    etcdctl ls /deployment/v1/loggregator-server/pool/$line >> zonelogser.txt
    while read temp
    do
        etcdctl get $temp >> /home/vcap/script/resources/zones/$line.txt
    done < zonelogser.txt
done < zonen.txt

#loggregator_trafficconntroller url register
etcdctl mkdir /deployment/v1/loggregator-traffic/traffic_url
etcdctl mkdir /deployment/v1/loggregator-traffic/index

rm -fr ltrafficdirs.txt /home/vcap/script/resources/ltraffic_urls.txt

etcdctl ls /deployment/v1/loggregator-traffic/traffic_url >> ltrafficdirs.txt

while read ltraffic_urls
do
etcdctl get $ltraffic_urls >> /home/vcap/script/resources/ltraffic_urls.txt
done < ltrafficdirs.txt

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/ltraffic_urls.txt`
    do
    if [ "$NISE_IP_ADDRESS" == "$j" ]
    then
        echo "the ip:$NISE_IP_ADDRESS is exits!"
        flag="true"
    fi
    done
    if [ "$flag" == "false" ]
    then
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/loggregator-traffic/traffic_url -XPOST -d value=$NISE_IP_ADDRESS

        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/loggregator-traffic/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/loggregator-traffic/index/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr ltrafficindexdirs.txt
            etcdctl ls /deployment/v1/loggregator-traffic/index >> ltrafficindexdirs.txt
            last=`sed -n '$=' ltrafficindexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/loggregator-traffic/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/loggregator-traffic/index >> oldindex.txt
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

#---------------- api base ---------------------
last=`sed -n '$=' /home/vcap/script/resources/natsip.txt`
i=1
while read line
do
if [ "$i" -eq "$last" ]
then
echo -e "\"$line\"" >> ltnats.txt
else
echo -e "\"$line\",\c" >> ltnats.txt
let i++
fi
done < /home/vcap/script/resources/natsip.txt

echo -e "https://api.$cc_base_url.xip.io" >> apiHost.txt

echo -e "$cc_base_url.xip.io" >> systemDomain.txt

#------------------------------- zone -------------------------------------
loggerator_num=`sed -n '$=' /home/vcap/script/resources/loggregator_url.txt`
zones_num=`sed -n '$=' /home/vcap/script/resources/cc_zone.txt`
log_traffic_num=`sed -n '$=' /home/vcap/script/resources/loggregator_endpoint.txt`
zone=""

[[ $(stat -c %s /home/vcap/script/resources/loggregator_endpoint.txt) -eq 0 ]] && log_traffic_num="0" && let log_traffic_num++

shitline=`expr $log_traffic_num % $zones_num`

if [ $log_traffic_num -le $zones_num ]
then
zone=`cat /home/vcap/script/resources/cc_zone.txt |sed -n ''$log_traffic_num'p'`
elif [ $shitline -eq 0 ]; then
zone=`tac /home/vcap/script/resources/cc_zone.txt |sed -n '1p'`
else
zone=`cat /home/vcap/script/resources/cc_zone.txt |sed -n ''$shitline'p'`
fi

#----------------------- loggerator servers --------------------------
#  "z1":["10.10.16.28"],"z2":["10.10.16.29"]
k=1
filelist=`ls /home/vcap/script/resources/zones/ |grep 'txt$'`
for file in $filelist
do
filename="${file%\.*}"
echo -e "\"$filename\":[\c" >> logurls.txt

last=`sed -n '$=' /home/vcap/script/resources/zones/$file`
j=1
while read logurl
do
if [ "$j" -eq "$last" ]
then
    echo -e "\"$logurl\"]\c" >> logurls.txt
else
    echo -e "\"$logurl\",\c" >> logurls.txt
    let j++
fi
done < /home/vcap/script/resources/zones/$file

pushd /home/vcap/script/resources/zones/
zone_num=`ls -l |grep "^-" |grep "txt$" |wc -l`
popd

if [ $k -eq $zone_num ]
then
    echo "oh this is end"
else
    echo -e ",\c" >> logurls.txt
    let k++
fi

done

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

#----------------------- end ------------------------------------------

loggerator_str=`more logurls.txt`
api_host=`more apiHost.txt`
sysdomain=`more systemDomain.txt`
nats_ip=`more ltnats.txt`
index=$(cat $indexfile)
etcd_urls=`more lstores.txt`

editlogtraffic "$index" "$etcd_urls" "$zone" "$api_host" "$sysdomain" "$nats_ip"

rm -fr apiHost.txt systemDomain.txt ltnats.txt logurls.txt lstores.txt
popd

#++++++++++++++++++++++ Loggerator Traffic Bin ++++++++++++++++++++++++++++++++
echo "TRAFFIC CONFIG INIT......"
cp -a $cfscriptdir/loggregator_trafficcontroller/bin/* $LOG_TRAFFICCONTROLLER_BIN/
chmod -R +x $LOG_TRAFFICCONTROLLER_BIN/
