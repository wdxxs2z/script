#!/bin/bash

source /home/vcap/script/gnatsd/register.sh

export PATH=/home/vcap/etcdctl/bin:$PATH

RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`
PACKAGES_DIR=/var/vcap/packages

if [ ! -d /var/vcap/packages ]; then
    sudo mkdir -p /var/vcap/packages
    sudo chown -R vcap:vcap /var/vcap/packages 
fi

wget -c -r -nd -P $PACKAGES_DIR http://$RESOURCE_URL/build/gnatsd.tar.gz

if [ ! -f $PACKAGES_DIR/gnatsd.tar.gz ]; then
    echo "This is an error postgres is not download correctly,please check your fileserver connect right."
    exit 1
fi

pushd $PACKAGES_DIR
    gunzip gnatsd.tar.gz
    tar -xf gnatsd.tar 
    rm -fr gnatsd.tar.gz gnatsd.tar
popd

source /home/vcap/script/monit/install.sh "nats"
