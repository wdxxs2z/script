#!/bin/bash

function editgorouter() {

echo "---

status:
  port: 18888
  user: gorouter
  pass: \"c1oudc0w\"


nats:

$1


logging:
  file: /var/vcap/sys/log/gorouter/gorouter.log
  
  syslog: vcap.gorouter
  
  level: info


loggregatorConfig:
  url: $2:13456
  shared_secret: c1oudc0w


port: 8888
index: $3
pidfile: /var/vcap/sys/run/gorouter/gorouter.pid
go_max_procs: 8
trace_key: 22
access_log: /var/vcap/sys/log/gorouter/access.log

publish_start_message_interval: 30
prune_stale_droplets_interval: 30
droplet_stale_threshold: 120
publish_active_apps_interval: 0 # 0 means disabled

endpoint_timeout: 300" > /var/vcap/jobs/gorouter/config/gorouter.yml

}

nats_url="$1"
loggregator_url="$2"
index="$3"

editgorouter "$1" "$2" "$3"

