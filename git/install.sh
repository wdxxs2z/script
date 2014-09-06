#!/bin/bash

homedir=/home/vcap

export PATH=/home/vcap/etcdctl/bin:$PATH
source /home/vcap/script/util/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt
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
