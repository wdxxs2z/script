#!/bin/bash

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

source /home/vcap/script/nginx/edit_nginx.sh

NGINX_CONFIG=/var/vcap/jobs/cloud_controller_ng/config
NGINX_BIN=/var/vcap/jobs/cloud_controller_ng/bin

#-------------------------- git init ----------------------------

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

    mkdir -p $NGINX_CONFIG
    mkdir -p $NGINX_BIN

#------------------------- Nginx --------------------------------
pushd /var/vcap/packages

if [ ! -d nginx ]; then
    mkdir -p /var/vcap/packages/nginx
fi

if [ ! -f nginx/pcre-8.34.tar.gz ]; then
    wget http://blob.cfblob.com/ee5bee99-dda0-4d81-be88-a7a1a901dae7
    mv ee5bee99-dda0-4d81-be88-a7a1a901dae7 nginx/pcre-8.34.tar.gz
fi

if [ ! -f nginx/headers-more-v0.25.tgz ]; then
    wget http://blob.cfblob.com/a621718d-df24-4205-ba31-6ed8a212732e
    mv a621718d-df24-4205-ba31-6ed8a212732e nginx/headers-more-v0.25.tgz
fi

if [ ! -f nginx/nginx-upload-module-2.2.tar.gz ]; then
    wget http://blob.cfblob.com/502854f1-9823-468f-baef-1a8d68823ead
    mv 502854f1-9823-468f-baef-1a8d68823ead nginx/nginx-upload-module-2.2.tar.gz
fi

if [ ! -f nginx/upload_module_put_support.patch ]; then
    cp -a /home/vcap/cf-release/src/nginx/upload_module_put_support.patch nginx/
fi

if [ ! -f nginx/nginx-1.4.5.tar.gz ]; then
    wget http://blob.cfblob.com/8001e14c-1629-4305-bd5a-02e6ec9faa04
    mv 8001e14c-1629-4305-bd5a-02e6ec9faa04 nginx/nginx-1.4.5.tar.gz
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
