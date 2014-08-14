#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/var/vcap/packages/loggregators/bin:$PATH
export GOPATH=/var/vcap/packages/loggregators

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

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages
    #rm -fr /var/vcap/packages/loggregator /var/vcap/packages/loggregator_trafficcontroller /var/vcap/packages/dea_logging_agent
    echo "Setup git checkout loggerators......"
    cp -a $homedir/cf-release/src/loggregator /var/vcap/packages
    mv /var/vcap/packages/loggregator /var/vcap/packages/loggregators
    cd $GOPATH/bin
    ./build-platforms
    ./build
   
    cd /var/vcap/packages/loggregators/src/loggregator
        go build
        cp ./loggregator /var/vcap/packages/loggregators/release/
    
    cd /var/vcap/packages/loggregators/src/trafficcontroller
        go build
        cp ./trafficcontroller /var/vcap/packages/loggregators/release/
    
    cd /var/vcap/packages/loggregators/src/deaagent/deaagent
        go build
        cp ./deaagent /var/vcap/packages/loggregators/release/
    
    echo "--------loggregator---------"
    mkdir -p /var/vcap/packages/loggregator
    mkdir -p /var/vcap/packages/loggregator_trafficcontroller
    mkdir -p /var/vcap/packages/dea_logging_agent
    
    cd /var/vcap/packages/loggregators/
    cp release/loggregator /var/vcap/packages/loggregator/
    cp release/trafficcontroller /var/vcap/packages/loggregator_trafficcontroller/
    cp release/deaagent /var/vcap/packages/dea_logging_agent/
    
    pushd /var/vcap/packages/

    mkdir -p /var/vcap/packages/common/

    cp -a /home/vcap/cf-release/src/common/* /var/vcap/packages/common/

    mkdir -p /var/vcap/packages/syslog_aggregator

    cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/
    
    tar -zcf loggregator.tar.gz loggregator common syslog_aggregator
    curl -F "action=/upload/build" -F "uploadfile=@loggregator.tar.gz" http://192.168.201.134:9090/upload/build
    
    tar -zcf loggregator_trafficcontroller.tar.gz loggregator_trafficcontroller common syslog_aggregator
    curl -F "action=/upload/build" -F "uploadfile=@loggregator_trafficcontroller.tar.gz" http://192.168.201.134:9090/upload/build
    
    tar -zcf dea_logging_agent.tar.gz dea_logging_agent common syslog_aggregator
    curl -F "action=/upload/build" -F "uploadfile=@dea_logging_agent.tar.gz" http://192.168.201.134:9090/upload/build
    
    rm -fr loggregator.tar.gz loggregator_trafficcontroller.tar.gz dea_logging_agent.tar.gz loggregators
       
    popd
    
    popd

echo "Loggregator install success!!"

