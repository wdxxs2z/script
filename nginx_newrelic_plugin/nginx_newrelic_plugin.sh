#!/bin/bash

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

NGINX_NEWRELIC_PLUGIN_CONFIG=/var/vcap/jobs/cloud_controller_ng/config
NGINX_NEWRELIC_PLUGIN_BIN=/var/vcap/jobs/cloud_controller_ng/bin

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

#-------------------------- git init -----------------------------------------

if [ ! -d $homedir/cf-release ]; then
    pushd $homedir
    git clone https://github.com/cloudfoundry/cf-release
    cd $homedir/cf-release
    git checkout c4dfff2
    git submodule update --init
    popd
fi

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi


if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

    mkdir -p $NGINX_NEWRELIC_PLUGIN_CONFIG
    mkdir -p $NGINX_NEWRELIC_PLUGIN_BIN

#-------------------------- nginx_newrelic_plugin ----------------------------
pushd /var/vcap/packages

if [ ! -d /var/vcap/packages/nginx ]; then
    mkdir -p /var/vcap/packages/nginx
fi

if [ ! -f nginx/newrelic_nginx_agent.tar.gz ]; then
    wget http://blob.cfblob.com/cad4fada-4a11-4b1a-a884-c6f58dacead9
    mv cad4fada-4a11-4b1a-a884-c6f58dacead9 nginx/newrelic_nginx_agent.tar.gz
fi

if [ ! -d /var/vcap/packages/nginx_newrelic_plugin ]; then
    mkdir -p /var/vcap/packages/nginx_newrelic_plugin
fi

tar zxvf nginx/newrelic_nginx_agent.tar.gz
cp -a newrelic_nginx_agent/* /var/vcap/packages/nginx_newrelic_plugin/

pushd /var/vcap/packages/nginx_newrelic_plugin
#bundle install 
bundle package --all
bundle install --local --deployment --without development test
popd

popd

#-------------------------- nginx_newrelic_plugin config ----------------------------
cp -a $cfscriptdir/cloud_controller_ng/config/newrelic_plugin.yml $NGINX_NEWRELIC_PLUGIN_CONFIG/

#-------------------------- nginx_newrelic_plugin_config ----------------------------
cp -a $cfscriptdir/cloud_controller_ng/bin/nginx_newrelic_plugin_ctl $NGINX_NEWRELIC_PLUGIN_BIN/
chmod +x $NGINX_NEWRELIC_PLUGIN_BIN/nginx_newrelic_plugin_ctl

echo "Nginx_newrelic_plugin installed complete!"
