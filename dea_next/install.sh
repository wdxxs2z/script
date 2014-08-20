#!/bin/bash
COMPONENT=dea_next

source /home/vcap/script/$COMPONENT/register.sh

export PATH=/home/vcap/etcdctl/bin:$PATH

RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`
PACKAGES_DIR=/var/vcap/packages

if [ ! -d /var/vcap/packages ]; then
    sudo mkdir -p /var/vcap/packages
    sudo chown -R vcap:vcap /var/vcap/packages 
fi

# 下载rootfs解压 /var/vcap/packages/
if grep -q -i ubuntu /etc/issue
then
    wget -P $PACKAGES_DIR http://$RESOURCE_URL/packages/rootfs/lucid64.tar.gz
    pushd $PACKAGES_DIR
        mkdir $PACKAGES_DIR/lucid64
        tar -zxf lucid64.tar.gz -C $PACKAGES_DIR/lucid64/ 
    popd
fi

if grep -q -i centos /etc/issue
then
    wget -P $PACKAGES_DIR http://$RESOURCE_URL/packages/rootfs/centos6.5.tar.gz
    pushd $PACKAGES_DIR
        tar -zxf centos6.5.tar.gz
    popd
fi

# 下载buildpack_cache /var/vcap/packages/build_packages_cache/
mkdir -p $PACKAGES_DIR/buildpack_cache
wget -c -r -nd -P $PACKAGES_DIR/buildpack_cache http://$RESOURCE_URL/packages/buildpack_cache

#Component
wget -P $PACKAGES_DIR http://$RESOURCE_URL/build/dea_next.tar.gz
wget -P $PACKAGES_DIR http://$RESOURCE_URL/build/warden.tar.gz

if [ ! -f $PACKAGES_DIR/dea_next.tar.gz ] && [ ! -f $PACKAGES_DIR/warden.tar.gz ]
then
    echo "This is an error dea and warden are not download correctly,please check your fileserver connect right."
    exit 1
fi

pushd $PACKAGES_DIR
    gunzip dea_next.tar.gz
    tar -xf dea_next.tar
    gunzip warden.tar.gz
    tar -xf warden.tar
    rm -fr dea_next.tar.gz dea_next.tar warden.tar.gz warden.tar
popd

source /home/vcap/script/monit/install.sh $COMPONENT
