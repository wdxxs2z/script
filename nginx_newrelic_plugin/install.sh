#!/bin/bash

COMPONENT=nginx_newrelic_plugin

source /home/vcap/script/$COMPONENT/register.sh
source /home/vcap/script/$COMPONENT/etcdinit.sh

RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`
PACKAGES_DIR=/var/vcap/packages

if [ ! -d /var/vcap/packages ]; then
    sudo mkdir -p /var/vcap/packages
    sudo chown -R vcap:vcap /var/vcap/packages 
fi

wget -c -r -nd -P $PACKAGES_DIR http://$RESOURCE_URL/build/$COMPONENT.tar.gz

if [ ! -f $PACKAGES_DIR/$COMPONENT.tar.gz ]; then
    echo "This is an error $COMPONENT is not download correctly,please check your fileserver connect right."
    exit 1
fi

pushd $PACKAGES_DIR
    gunzip $COMPONENT.tar.gz
    tar -xf $COMPONENT.tar 
    rm -fr $COMPONENT.tar.gz $COMPONENT.tar
popd
