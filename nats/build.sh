#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

export PATH=/home/vcap/etcdctl/bin:$PATH
source /home/vcap/script/nats/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt
RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

#--------------- git clone ----------------------
if ! (which ruby); then
    echo "Ruby is not or error setup,please install ruby......"
    exit 1;
fi

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "git init nats_stream_forword"
pushd $homedir/cf-release
cd src/nats
git submodule update --init
popd

mkdir -p /var/vcap/packages/nats/nats
cp -a $homedir/cf-release/src/nats/* /var/vcap/packages/nats/nats

pushd /var/vcap/packages/nats/nats
bundle package --all
bundle install --local --deployment --without development test
popd

pushd /var/vcap/packages

    tar -zcf nats.tar.gz nats
    curl -F "action=/upload/build" -F "uploadfile=@nats.tar.gz" http://$RESOURCE_URL/upload/build
    
popd

echo "Nats stream is alread installed success."
