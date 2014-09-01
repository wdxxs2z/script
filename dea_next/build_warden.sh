#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

homedir=/home/vcap
cfdir=/home/vcap/cf-release

export PATH=/home/vcap/etcdctl/bin:$PATH
source /home/vcap/script/dea_next/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt
RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

echo "---------------Warden-------------------"

if ! (which ruby); then
    echo "Ruby is not or error setup,please install ruby......"
    exit 1;
fi

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown -R vcap:vcap /var/vcap
fi
    
if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

mkdir -p /var/vcap/jobs/dea_next/bin
mkdir -p /var/vcap/jobs/dea_next/config 
mkdir -p /var/vcap/sys/log/warden
mkdir -p /var/vcap/sys/run/warden

#ubuntu and centos warden importent
mkdir -p /var/vcap/packages
pushd /var/vcap/packages
cp -a $cfdir/src/warden /var/vcap/packages/
cd /var/vcap/packages/warden/warden
cp /home/vcap/script/dea_next/common.sh /var/vcap/packages/warden/warden/root/linux/skeleton/lib/
bundle package --all
bundle install --local --deployment --without development test
bundle exec rake setup:bin
popd

pushd /var/vcap/packages
tar -zcf warden.tar.gz warden

curl -F "action=/upload/build" -F "uploadfile=@warden.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr warden.tar.gz
popd

echo "Warden is already installed success!!"