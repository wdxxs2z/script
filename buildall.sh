#!/bin/bash

echo "*************************************************************"
echo "*             build all cloudfoundry com                    *"
echo "*************************************************************"

SCRIPTDIR=/home/vcap/script

#env script
export PATH=$PATH:/home/vcap/script/
chmod +x -R /home/vcap/script/*
source $SCRIPTDIR/environment/libdepUtil.sh
source $SCRIPTDIR/environment/golang.sh
source $SCRIPTDIR/environment/ruby.sh
source $SCRIPTDIR/environment/rubyenv.sh

#com script
source $SCRIPTDIR/etcdctl/build.sh
source $SCRIPTDIR/cf-prepare/cf-verison.sh
rm -fr /var/vcap/packages/etcd
source $SCRIPTDIR/etcd/build.sh
rm -fr /var/vcap/packages/etcd_metrics_server
source $SCRIPTDIR/etcd_metrics_server/build.sh
rm -fr /var/vcap/packages/postgres
source $SCRIPTDIR/postgres/build.sh
rm -fr /var/vcap/packages/gnatsd
source $SCRIPTDIR/gnatsd/build.sh
rm -fr /var/vcap/packages/nats
source $SCRIPTDIR/nats/build.sh
rm -fr /var/vcap/packages/uaa
source $SCRIPTDIR/uaa/build.sh
rm -fr /var/vcap/packages/loggregator
source $SCRIPTDIR/loggregator/build.sh
rm -fr /var/vcap/packages/nginx
source $SCRIPTDIR/nginx/install.sh
rm -fr /var/vcap/packages/nginx_newrelic_plugin
source $SCRIPTDIR/nginx_newrelic_plugin/build.sh
rm -fr /var/vcap/packages/cloud_controller_ng
source $SCRIPTDIR/cloud_controller_ng/build.sh
rm -fr /var/vcap/packages/dea_next
source $SCRIPTDIR/dea_next/build_dea.sh
rm -fr /var/vcap/packages/warden
source $SCRIPTDIR/dea_next/build_warden.sh
rm -fr /var/vcap/packages/hm9000
source $SCRIPTDIR/hm9000/build.sh
rm -fr /var/vcap/packages/gorouter
source $SCRIPTDIR/gorouter/build.sh