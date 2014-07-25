#!/bin/bash
homeDir=/home/vcap

if [ ! -d $homeDir/jdk/bin ]; then
    echo "JDK is not set up,this step will download 2 jdk,one sun,one no sun!"

    mkdir -p $homeDir/jdk
    mkdir -p $homeDir/Downloads

    if [ ! -f $homeDir/Downloads/jdk-7u60-linux-x64.tar.gz ]; then
    	echo "Sun jdk will be setup......"
	wget -P $homeDir/Downloads ftp://61.135.158.199/pub/jdk-7u60-linux-x64.tar.gz 
    fi

    tar zxvf $homeDir/Downloads/jdk-7u60-linux-x64.tar.gz -C $homeDir/Downloads

    pushd $homeDir/Downloads/jdk1.7.0_60
    cp -a $homeDir/Downloads/jdk1.7.0_60 $homeDir/jdk
    popd

    echo "Set up jdk env......"
    echo "export JAVA_HOME=/home/vcap/jdk/jdk1.7.0_60" >> ~/.bashrc 
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.bashrc 
    echo "export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar" >> ~/.bashrc

    source ~/.bashrc
fi
