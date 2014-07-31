#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

NATS_STREAM_FORWORD_CONFIG=/var/vcap/jobs/nats_stream_forwarder/config
NATS_STREAM_FORWORD_BIN=/var/vcap/jobs/nats_stream_forwarder/bin

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

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

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

pushd $homedir/cf-release/src/nats
bundle package --all
popd

mkdir -p /var/vcap/packages/nats/nats
cp -a $homedir/cf-release/src/nats/* /var/vcap/packages/nats/nats

pushd /var/vcap/packages/nats/nats
/var/vcap/packages/ruby/bin/bundle install --local --deployment --without development test
popd

#-------------------- nats_stream_forwarder --------------------------
mkdir -p $NATS_STREAM_FORWORD_CONFIG
mkdir -p $NATS_STREAM_FORWORD_BIN

pushd /var/vcap/jobs/nats_stream_forwarder

rm -fr $NATS_STREAM_FORWORD_BIN/nats_stream_forwarder_ctl

cp -a $homedir/cf-config-script/nats_stream_forwarder/bin/nats_stream_forwarder.rb $NATS_STREAM_FORWORD_BIN/
cp -a $homedir/cf-config-script/nats_stream_forwarder/config/* $NATS_STREAM_FORWORD_CONFIG/

cp -a $homedir/cf-config-script/nats_stream_forwarder/bin/nats_stream_forwarder_ctl $NATS_STREAM_FORWORD_BIN/

#modify the nats_stream_forwarder_ctl

sed -i "s/192.168.64.142/${NISE_IP_ADDRESS}/g" `grep 192.168.64.142 -rl $NATS_STREAM_FORWORD_BIN`

chmod -R +x $NATS_STREAM_FORWORD_BIN/

popd
