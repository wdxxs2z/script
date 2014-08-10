#!/bin/bash

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

homedir=/home/vcap

if ! (which ruby); then
    echo "Ruby is not or error setup,please install ruby......"
    exit 1;
fi

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

echo "git init cloud_controller_ng"
pushd $homedir/cf-release
cd src/cloud_controller_ng
git submodule update --init
popd

if [ ! -d /var/vcap/packages/cloud_controller_ng ]; then
    mkdir -p /var/vcap/packages/cloud_controller_ng
fi

cp -a $homedir/cf-release/src/cloud_controller_ng/* /var/vcap/packages/cloud_controller_ng

#------------------------ Resolve the cloud_controller_ng depdens ------
if [ ! -d /var/vcap/packages ]; then 
    mkdir -p /var/vcap/packages
fi

pushd /var/vcap/packages

# libpq
if [ ! -f postgresql-9.0.3.tar.gz ]; then   
    wget http://192.168.201.128:9090/packages/postgres/postgresql-9.0.3.tar.gz
fi

mkdir -p /var/vcap/packages/libpq

tar xzf postgresql-9.0.3.tar.gz

cd postgresql-9.0.3

./configure --prefix=/var/vcap/packages/libpq

pushd src/bin/pg_config
  make
  make install
popd

cp -LR src/include /var/vcap/packages/libpq

pushd src/interfaces/libpq
  make
  make install
popd

rm -fr /var/vcap/packages/postgresql-9.0.3
popd

pushd /var/vcap/packages

#client-mysql
if [ ! -f client-5.1.62-rel13.3-435-Linux-x86_64.tar.gz ]; then
    wget http://192.168.201.128:9090/packages/mysql/client-5.1.62-rel13.3-435-Linux-x86_64.tar.gz
fi

VERSION=5.1.62-rel13.3-435-Linux-x86_64
# Percona binary Linux build - minor change
tar zxvf client-$VERSION.tar.gz

cd client-$VERSION
for x in bin include lib; do
  cp -a ${x} /var/vcap/packages/mysqlclient
done

rm -fr /var/vcap/packages/client-$VERSION
popd

pushd /var/vcap/packages
#sqlite
if [ ! -f sqlite-autoconf-3070500.tar.gz ]; then
    wget http://192.168.201.128:9090/packages/sqlite/sqlite-autoconf-3070500.tar.gz
fi

tar xzf sqlite-autoconf-3070500.tar.gz
mkdir -p /var/vcap/packages/sqlite

cd sqlite-autoconf-3070500

./configure --prefix=/var/vcap/packages/sqlite
make
make install

rm -fr /var/vcap/packages/sqlite-autoconf-3070500 
popd

#--------------------------------- Cloud_controller_ng install -----------
pushd /var/vcap/packages/cloud_controller_ng

bundle package --all

mysqlclient_dir=/var/vcap/packages/mysqlclient
libpq_dir=/var/vcap/packages/libpq

bundle config build.mysql2 --with-mysql-dir=$mysqlclient_dir --with-mysql-include=$mysqlclient_dir/include/mysql
bundle config build.pg --with-pg-lib=$libpq_dir/lib --with-pg-include=$libpq_dir/include
bundle config build.sqlite3 --with-sqlite3-dir=/var/vcap/packages/sqlite
bundle install --local --deployment --without development test

pushd /var/vcap/packages/

mkdir -p /var/vcap/packages/common/

cp -a /home/vcap/cf-release/src/common/* /var/vcap/packages/common/

mkdir -p /var/vcap/packages/syslog_aggregator

cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/

tar -zcvf cloud_controller_ng.tar.gz cloud_controller_ng libpq mysqlclient sqlite common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@cloud_controller_ng.tar.gz" http://192.168.201.128:9090/upload/build

rm -fr cloud_controller_ng.tar.gz sqlite-autoconf-3070500.tar.gz client-5.1.62-rel13.3-435-Linux-x86_64.tar.gz postgresql-9.0.3.tar.gz

popd

popd
