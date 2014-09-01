#!/bin/bash

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

NGINX_NEWRELIC_PLUGIN_CONFIG=/var/vcap/jobs/cloud_controller_ng/config
NGINX_NEWRELIC_PLUGIN_BIN=/var/vcap/jobs/cloud_controller_ng/bin

export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*

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

#-------------------------- nginx_newrelic_plugin config ----------------------------
cp -a $cfscriptdir/cloud_controller_ng/config/newrelic_plugin.yml $NGINX_NEWRELIC_PLUGIN_CONFIG/

#-------------------------- nginx_newrelic_plugin_config ----------------------------
cp -a $cfscriptdir/cloud_controller_ng/bin/nginx_newrelic_plugin_ctl $NGINX_NEWRELIC_PLUGIN_BIN/
chmod +x $NGINX_NEWRELIC_PLUGIN_BIN/nginx_newrelic_plugin_ctl

echo "Nginx_newrelic_plugin installed complete!"
