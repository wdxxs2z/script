#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

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

pushd /var/vcap/packages

    tar -zcf nats.tar.gz nats
    curl -F "action=/upload/build" -F "uploadfile=@nats.tar.gz" http://192.168.201.134:9090/upload/build
    
popd

echo "Nats stream is alread installed success."
