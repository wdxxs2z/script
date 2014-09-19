#!/bin/bash

function editlog() {

echo "{
  \"EtcdUrls\": [$1],
  \"EtcdMaxConcurrentRequests\": 10,
  \"WSMessageBufferSize\": 100,
  \"LegacyIncomingMessagesPort\": 3456,
  \"DropsondeIncomingMessagesPort\": 3457,
  \"OutgoingPort\": 38080,
  \"Zone\": \"$4\",
  \"SkipCertVerify\": true,
  \"JobName\": \"micro_ng\",
  \"Index\": $3,
  \"MaxRetainedLogMessages\": 100,
  \"SharedSecret\": \"c1oudc0w\",

  \"NatsHosts\": [$2],
  \"NatsPort\": 4222,
  \"NatsUser\": \"nats\",
  \"NatsPass\": \"c1oudc0w\",
  \"VarzUser\": \"loggregator\",
  \"VarzPass\": \"c1oudc0w\",
  \"VarzPort\": 5768,
  \"InactivityDurationInMilliseconds\": 3600000
    
    , \"Syslog\": \"vcap.loggregator\"
    
    
}" >> /var/vcap/jobs/loggregator/config/loggregator.json


}

etcd="$1"
nats_urls="$2"
index="$3"
zone="$4"

editlog "$1" "$2" "$3" "$4"
