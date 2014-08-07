#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/loggregator/bin:$PATH
export GOPATH=/var/vcap/packages/loggregator

homedir=/home/vcap

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "LOGGREGATOR GIT INIT......"
pushd $homedir/cf-release
cd src/loggregator
git submodule update --init
popd

if [ ! -d /var/vcap/jobs/loggregator ]; then
    mkdir -p $LOGGREGATOR_CONFIG
    mkdir -p $LOGGREGATOR_BIN 
fi

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages

    echo "Setup git checkout loggerators......"
    cp -a $homedir/cf-release/src/loggregator /var/vcap/packages
    cd $GOPATH/bin
    ./build-platforms
    ./build
    cd $GOPATH
    echo "--------loggregator---------"
    mv release/loggregator /var/vcap/packages/loggregator/loggregator
    mv release/trafficcontroller /var/vcap/packages/loggregator_trafficcontroller/trafficcontroller
    mv release/deaagent /var/vcap/packages/dea_logging_agent/deaagent
    
    pushd /var/vcap/packages/
    
    tar -zcvf loggregator.tar.gz loggregator
    curl -F "action=/upload/build" -F "uploadfile=@loggregator.tar.gz" http://192.168.201.128:9090/upload/build
    
    tar -zcvf loggregator_trafficcontroller.tar.gz loggregator_trafficcontroller
    curl -F "action=/upload/build" -F "uploadfile=@loggregator_trafficcontroller.tar.gz" http://192.168.201.128:9090/upload/build
    
    tar -zcvf dea_logging_agent.tar.gz dea_logging_agent
    curl -F "action=/upload/build" -F "uploadfile=@dea_logging_agent.tar.gz" http://192.168.201.128:9090/upload/build
       
    popd
    
    popd

echo "Loggregator install success!!"

