#!/bin/bash

echo "*************************************************************"
echo "*             build all cloudfoundry com                    *"
echo "*************************************************************"

SCRIPTDIR=/home/vcap/script

#env script
source $SCRIPTDIR/environment/libdepUtil.sh
source $SCRIPTDIR/environment/golang.sh
source $SCRIPTDIR/environment/ruby.sh
source $SCRIPTDIR/environment/rubyenv.sh

#com script
source $SCRIPTDIR/etcd/build.sh
source $SCRIPTDIR/postgres/build.sh
source $SCRIPTDIR/gnatsd/build.sh
source $SCRIPTDIR/nats/nats.sh
source $SCRIPTDIR/uaa/build.sh
source $SCRIPTDIR/loggregator/build.sh
source $SCRIPTDIR/nginx/install.sh
source $SCRIPTDIR/nginx_newrelic_plugin/build.sh
source $SCRIPTDIR/cloud_controller_ng/build.sh
source $SCRIPTDIR/dea_next/build.sh
source $SCRIPTDIR/hm9000/build.sh
source $SCRIPTDIR/gorouter/build.sh
source $SCRIPTDIR/haproxy/haproxy.sh
