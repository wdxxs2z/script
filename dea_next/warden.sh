#!/bin/bash

homedir=/home/vcap
cfdir=/home/vcap/cf-release
cfscriptdir=/home/vcap/cf-config-script
WARDEN_CONF_DIR=/var/vcap/jobs/dea_next/config
WARDEN_BIN_DIR=/var/vcap/jobs/dea_next/bin
export PATH=/home/vcap/ruby/bin:$PATH
export RUBY_PATH=/home/vcap/ruby:$RUBY_PATH
export WARDEN_GEMFILE=/var/vcap/packages/warden/warden/Gemfile
cgroup=`awk '/cgroup/ {print $0}' /etc/default/grub`
cgroup2="GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\""

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
    pushd $homedir
    git clone https://github.com/cloudfoundry/cf-release
    sudo chown -R vcap:vcap cf-release 
    cd $homedir/cf-release
    git checkout c4dfff2
    git submodule update --init
    popd
fi

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    sudo chown -R cf-config-script
    popd
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
  	git checkout 1828c6f56f
	git submodule update --init 
	rm -fr warden/config/linux.yml
 	cp -a $cfscriptdir/dea_next/config/warden.yml warden/config/linux.yml
        cp -a $cfscriptdir/dea_next/config/warden.yml $WARDEN_CONF_DIR
	cd warden
        bundle install
        bundle exec rake setup[$WARDEN_CONF_DIR/warden.yml]
        cp -a $cfscriptdir/dea_next/bin/warden_ctl $WARDEN_BIN_DIR
	chmod +x $WARDEN_BIN_DIR/warden_ctl
    popd

if [[ $cgroup != $cgroup2 ]]; 
then
    sudo echo "GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"" >> /etc/default/grub 
    sudo /usr/sbin/update-grub
fi

echo "Warden already install ok! Please reboot your computer."
