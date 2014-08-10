#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi


if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

#-------------------------- nginx_newrelic_plugin ----------------------------
pushd /var/vcap/packages

if [ ! -d /var/vcap/packages/nginx ]; then
    mkdir -p /var/vcap/packages/nginx
fi

if [ ! -f nginx/newrelic_nginx_agent.tar.gz ]; then
    wget -P nginx/ http://192.168.201.128:9090/packages/nginx/newrelic_nginx_agent.tar.gz
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

pushd /var/vcap/packages/

tar -zcvf nginx_newrelic_plugin.tar.gz nginx_newrelic_plugin

curl -F "action=/upload/build" -F "uploadfile=@nginx_newrelic_plugin.tar.gz" http://192.168.201.128:9090/upload/build

rm -fr nginx_newrelic_plugin.tar.gz

popd

popd
