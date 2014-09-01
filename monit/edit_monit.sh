#!/bin/bash

function edit_monit() {

mkdir -p /var/vcap/monit
mkdir -p /var/vcap/bosh/etc

echo -e "set daemon 20
set logfile /var/vcap/monit/monit.log

set mmonit http://monit:monit@$2/collector

set httpd port 2822 and use address $1
  allow cleartext /var/vcap/monit/monit.user
  allow $3

include /var/vcap/monit/*.monitrc
include /var/vcap/monit/job/*.monitrc
" > /var/vcap/bosh/etc/monitrc

echo -e "vcap:$4" > /var/vcap/monit/monit.user

}

localhost="$1"
monitserver="$2"
acl="$3"
monitpasswd="$4"

edit_monit "$1" "$2" "$3" "$4"
