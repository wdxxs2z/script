#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH
export WARDEN_GEMFILE=/var/vcap/packages/warden/warden/Gemfile

homedir=/home/vcap
cfdir=/home/vcap/cf-release
cfscriptdir=/home/vcap/cf-config-script

export PATH=/home/vcap/etcdctl/bin:$PATH
RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`

echo "---------------Warden-------------------"

if ! (which ruby); then
    echo "Ruby is not or error setup,please install ruby......"
    exit 1;
fi

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown -R vcap:vcap /var/vcap
fi
    
if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

mkdir -p /var/vcap/jobs/dea_next/bin
mkdir -p /var/vcap/jobs/dea_next/config 
mkdir -p /var/vcap/sys/log/warden
mkdir -p /var/vcap/sys/run/warden

echo "This step will always be install......"
    mkdir -p /var/vcap/packages
    pushd /var/vcap/packages
    	echo "Setup git clone warden 1828c6f56f"
        git clone https://github.com/cloudfoundry/warden
   	cd warden
	git submodule update --init
        git pull origin master
        git checkout 64683f4b682dd3a2fcaed37d83d110cef12fc5b3
	rm -fr warden/config/linux.yml
 	cp -a $cfscriptdir/dea_next/config/warden.yml warden/config/linux.yml
        cp -a $cfscriptdir/dea_next/config/warden.yml $WARDEN_CONF_DIR
	cd warden
        bundle install
        bundle install --local --deployment --without development test
        bundle exec rake setup:bin
    popd

pushd /var/vcap/packages
tar -zcf warden.tar.gz warden

curl -F "action=/upload/build" -F "uploadfile=@warden.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr warden.tar.gz
popd

echo "Warden is already installed success!!"
