#!/bin/bash

homedir=/home/vcap
export PATH=/var/vcap/packages/etcd/bin:$PATH
RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

mkdir -p /var/vcap/packages/git

pushd /var/vcap/packages/git

wget http://$RESOURCE_URL/packages/git/git-1.7.11.2.tar.gz

tar xzf git-1.7.11.2.tar.gz

cd git-1.7.11.2
./configure --prefix=/var/vcap/packages/git
make NO_TCLTK=Yes NO_PYTHON=Yes
make NO_TCLTK=Yes NO_PYTHON=Yes install

popd

rm -fr /var/vcap/packages/git/git-1.7.11.2 /var/vcap/packages/git/git-1.7.11.2.tar.gz

echo "Git install success!"
