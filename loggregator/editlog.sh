#!/bin/bash

function editlog() {

echo "{
  \"EtcdUrls\": [$1],
  \"EtcdMaxConcurrentRequests\" : 10,
  \"IncomingPort\": 3456,
  \"OutgoingPort\": 38080,
  \"SkipCertVerify\": true,
  \"Index\": $3,
  \"MaxRetainedLogMessages\": 100,
  \"SharedSecret\": \"c1oudc0w\",

  \"NatsHosts\": [$2],
  \"NatsPort\": 4222,
  \"NatsUser\": \"nats\",
  \"NatsPass\": \"c1oudc0w\",
  \"VarzUser\": \"loggregator\",
  \"VarzPass\": \"c1oudc0w\",
  \"VarzPort\": 5768
    
    , \"Syslog\": \"vcap.loggregator\"
    
    
}" >> /var/vcap/jobs/loggregator/config/loggregator.json


}

etcd="$1"
nats_urls="$2"
index="$3"

editlog "$1" "$2" "$3"
