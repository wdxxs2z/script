#!/bin/bash

cfscriptdir=/home/vcap/cf-dep-configuration
homedir=/home/vcap

NATS_STREAM_FORWORD_CONFIG=/var/vcap/jobs/nats_stream_forwarder/config
NATS_STREAM_FORWORD_BIN=/var/vcap/jobs/nats_stream_forwarder/bin

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
fi

if [ ! -d $homedir/cf-dep-configuration ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-dep-configuration
    popd
fi
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
