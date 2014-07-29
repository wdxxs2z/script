#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/loggregator/bin:$PATH
export GOPATH=/var/vcap/packages/loggregator

LOG_TRAFFICCONTROLLER_CONFIG=/var/vcap/jobs/loggregator_trafficcontroller/config
LOG_TRAFFICCONTROLLER_BIN=/var/vcap/jobs/loggregator_trafficcontroller/bin

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

source /home/vcap/script/loggregator_trafficcontroller/editlogtraffic.sh

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

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

mkdir -p $LOG_TRAFFICCONTROLLER_CONFIG
mkdir -p $LOG_TRAFFICCONTROLLER_BIN

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages

    echo "Setup git checkout logging traffic ......"
    cp -a $homedir/cf-release/src/loggregator /var/vcap/packages
    cd $GOPATH/bin
    ./build-platforms
    ./build
    cd $GOPATH
    echo "--------loggregator_traficcontroller-----------"
    mkdir -p /var/vcap/packages/loggregator_trafficcontroller
    mv release/trafficcontroller-linux-amd64 /var/vcap/packages/loggregator_trafficcontroller/trafficcontroller
    popd

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
source /home/vcap/script/loggregator_trafficcontroller/etcdinit.sh
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
rm -fr traffic_dirs.txt
rm -fr /home/vcap/script/resources/loggregator_endpoint.txt
flag="true"

etcdctl ls /deployment/v1/loggregator-traffic/traffic_url >> traffic_dirs.txt

while read line
do
    etcdctl get $line >> /home/vcap/script/resources/loggregator_endpoint.txt
done < traffic_dirs.txt

while read line
do
    if [ "$line" == "$NISE_IP_ADDRESS" ]; then
        flag="false"
        echo "The ip is exit in loggregator_endpoint : $line"
        break
    fi
done < /home/vcap/script/resources/loggregator_endpoint.txt

if [ "$flag" == "true" ]; then
    curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/loggregator-traffic/traffic_url -XPOST -d value=$NISE_IP_ADDRESS
    echo "$NISE_IP_ADDRESS" >> /home/vcap/script/resources/loggregator_endpoint.txt
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

#----------------------- end ------------------------------------------

loggerator_str=`more logurls.txt`
api_host=`more apiHost.txt`
sysdomain=`more systemDomain.txt`
nats_ip=`more ltnats.txt`

editlogtraffic "$zone" "$loggerator_str" "$api_host" "$sysdomain" "$nats_ip"

rm -fr apiHost.txt systemDomain.txt ltnats.txt logurls.txt
popd

#++++++++++++++++++++++ Loggerator Traffic Bin ++++++++++++++++++++++++++++++++
echo "TRAFFIC CONFIG INIT......"
cp -a $cfscriptdir/loggregator_trafficcontroller/bin/* $LOG_TRAFFICCONTROLLER_BIN/
chmod -R +x $LOG_TRAFFICCONTROLLER_BIN/