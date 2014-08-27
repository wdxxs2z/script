#!/bin/bash

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

HAPROXY_CONFIG=/var/vcap/jobs/haproxy/config
HAPROXY_BIN=/var/vcap/jobs/haproxy/bin

source /home/vcap/script/haproxy/edit_haproxy.sh

#------------------------ git init ------------------------------

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi


if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

if [ ! -d /var/vcap/jobs/haproxy ]; then
    mkdir -p $HAPROXY_CONFIG
    mkdir -p $HAPROXY_BIN
fi

#------------------------ Haproxy -------------------------------

pushd /var/vcap/packages

if [ ! -d /var/vcap/packages/haproxy ]; then
    mkdir -p /var/vcap/packages/haproxy
fi

if [ ! -f haproxy/pcre-8.33.tar.gz ]; then
    wget -P haproxy/ http://192.168.201.128:9090/packages/haproxy/pcre-8.33.tar.gz
fi

if [ ! -f haproxy/haproxy-1.5-dev19.tar.gz ]; then
    wget -P haproxy/ http://192.168.201.128:9090/packages/haproxy/haproxy-1.5-dev19.tar.gz   
fi

echo "Extracting pcre..."
tar xzf haproxy/pcre-8.33.tar.gz
cd pcre-8.33
sudo ./configure
sudo make
sudo make install
cd ..

tar xzf haproxy/haproxy-1.5-dev19.tar.gz
cd haproxy-1.5-dev19
make TARGET=linux2628 USE_OPENSSL=1 USE_STATIC_PCRE=1
mkdir -p /var/vcap/packages/haproxy/bin
cp haproxy /var/vcap/packages/haproxy/bin/
chmod 755 /var/vcap/packages/haproxy/bin/haproxy

popd

#------------------------ Haproxy config -------------------------
pushd $HAPROXY_CONFIG
cp -a $cfscriptdir/haproxy/config/* $HAPROXY_CONFIG/
rm -fr $HAPROXY_CONFIG/haproxy.config

#etcdctl init
source /home/vcap/script/gorouter/etcdinit.sh
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl
rm -fr /home/vcap/script/resources/router.txt routerdirs.txt

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

pushd /home/vcap/etcdctl

./build

source /home/vcap/script/dea_next/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

popd

#router
etcdctl ls /deployment/v1/gorouter/router >> routerdirs.txt

while read router
do
    etcdctl get $router >> /home/vcap/script/resources/router.txt
done < routerdirs.txt

#register haproxy
etcdctl mkdir /deployment/v1/haproxy/haprxoy_url
rm -fr haproxy_dirs.txt
rm -fr /home/vcap/script/resources/haproxy.txt

flag="true"

etcdctl ls /deployment/v1/haproxy/haprxoy_url >> haproxy_dirs.txt

while read line
do
    etcdctl get $line >> /home/vcap/script/resources/haproxy.txt
done < haproxy_dirs.txt

while read line
do
    if [ "$line" == "$NISE_IP_ADDRESS" ]; then
        flag="false"
        echo "The ip is exit in haproxy : $line"
        break
    fi
done < /home/vcap/script/resources/haproxy.txt

if [ "$flag" == "true" ]; then
    curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/haproxy/haprxoy_url -XPOST -d value=$NISE_IP_ADDRESS
    echo "$NISE_IP_ADDRESS" >> /home/vcap/script/resources/haproxy.txt
fi

#--------------------- router in the haproxy -------------------------
node_index=0
while read line
do
echo -e "server node$node_index $line:8888 check inter 1000" >> rhaproxy.txt
let node_index++
done < /home/vcap/script/resources/router.txt

router_urls=`more rhaproxy.txt`

edit_haproxy "$router_urls"

rm -fr rhaproxy.txt routerdirs.txt haproxy_dirs.txt

popd

#---------------------- Haproxy bin ------------------------------
cp -a $cfscriptdir/haproxy/bin/* $HAPROXY_BIN

chmod -R +x $HAPROXY_BIN/*

echo "Haproxy install complete!"
