#!/bin/bash

echo "********************************************"
echo "*             This is monit script         *"
echo "********************************************"

export PATH=/home/vcap/etcdctl/bin:$PATH
RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

#comform the vcap dir
if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

#mkdir monit dir
mkdir -p /var/vcap/bosh

pushd /var/vcap
#Download the monit source to var/vcap/bosh
wget -P bosh/ wget -P bosh/ http://$RESOURCE_URL/packages/monit/monit-5.8.1.tar.gz
tar zxf bosh/monit-5.8.1.tar.gz
cd monit-5.8.1
./configure --prefix=/var/vcap/bosh
make && make install
cd ..
rm -fr monit-5.8.1.tar.gz monit-5.8.1
popd
