#!/bin/bash

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

source /home/vcap/script/nginx/edit_nginx.sh

NGINX_CONFIG=/var/vcap/jobs/cloud_controller_ng/config
NGINX_BIN=/var/vcap/jobs/cloud_controller_ng/bin

#-------------------------- git init ----------------------------

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
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

    mkdir -p $NGINX_CONFIG
    mkdir -p $NGINX_BIN

#------------------------- Nginx --------------------------------
pushd /var/vcap/packages

if [ ! -d nginx ]; then
    mkdir -p /var/vcap/packages/nginx
fi

if [ ! -f nginx/pcre-8.34.tar.gz ]; then
    wget -P nginx/ http://192.168.201.128:9090/packages/nginx/pcre-8.34.tar.gz
fi

if [ ! -f nginx/headers-more-v0.25.tgz ]; then
    wget -P nginx/ http://192.168.201.128:9090/packages/nginx/headers-more-v0.25.tgz
fi

if [ ! -f nginx/nginx-upload-module-2.2.tar.gz ]; then
    wget -P nginx/ http://192.168.201.128:9090/packages/nginx/nginx-upload-module-2.2.tar.gz
fi

if [ ! -f nginx/upload_module_put_support.patch ]; then
    cp -a /home/vcap/cf-release/src/nginx/upload_module_put_support.patch nginx/
fi

if [ ! -f nginx/nginx-1.4.5.tar.gz ]; then
    wget -P nginx/ http://192.168.201.128:9090/packages/nginx/nginx-1.4.5.tar.gz
fi

echo "Extracting pcre..."
tar xzvf nginx/pcre-8.34.tar.gz

echo "Extracting headers-more module..."
tar xzvf nginx/headers-more-v0.25.tgz

echo "Extracting nginx_upload module..."
tar xzvf nginx/nginx-upload-module-2.2.tar.gz

echo "Patching upload module"
pushd nginx-upload-module-2.2
  patch < ../nginx/upload_module_put_support.patch
popd

echo "Extracting nginx..."
tar xzvf nginx/nginx-1.4.5.tar.gz

echo "Building nginx..."
pushd nginx-1.4.5
  ./configure \
    --prefix=/var/vcap/packages/nginx \
    --with-pcre=../pcre-8.34 \
    --add-module=../headers-more-nginx-module-0.25 \
    --add-module=../nginx-upload-module-2.2 \
    --with-http_stub_status_module

  make
  make install
popd

rm -fr upload_module_put_support.patch nginx-1.4.5 nginx-upload-module-2.2 pcre-8.34 headers-more-nginx-module-0.25
popd

#---------------------------- Nginx config ---------------------------
cp -a $cfscriptdir/cloud_controller_ng/config/nginx.conf $NGINX_CONFIG/

#---------------------------- Nginx bin ------------------------------
cp -a $cfscriptdir/cloud_controller_ng/bin/nginx_ctl $NGINX_BIN/
chmod +x $NGINX_BIN/nginx_ctl
