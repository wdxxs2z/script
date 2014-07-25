#!/bin/bash
homedir=/home/vcap

if [ ! -d $homedir/go/bin ]; then

    mkdir -p $homedir/Downloads

    if [ ! -f $homedir/Downloads/go1.2.1.linux-amd64.tar.gz ]; then
        wget -P $homedir/Downloads http://gopher.qiniudn.com/download/go/go1.2.1.linux-amd64.tar.gz
    fi

    tar zxvf $homedir/Downloads/go1.2.1.linux-amd64.tar.gz -C $homedir
    
    echo "export GOROOT=/home/vcap/go" >> ~/.bashrc 
    echo "export GOARCH=amd64" >> ~/.bashrc 
    echo "export GOOS=linux" >> ~/.bashrc
    echo "export GOBIN=\$GOROOT/bin" >> ~/.bashrc 
    echo "export PATH=.:\$PATH:\$GOBIN" >> ~/.bashrc 
    echo "export GOPATH=/home/vcap/gopath" >> ~/.bashrc 
  
    mkdir -p /home/vcap/gopath

    source ~/.bashrc
fi
