#!/bin/bash

function editmetron() {

echo "{
  \"EtcdUrls\": [$1],
  \"EtcdMaxConcurrentRequests\": 10,
  \"SharedSecret\": \"c1oudc0w\",
  \"LegacyIncomingMessagesPort\": 3456,
  \"DropsondeIncomingMessagesPort\": 3457,
  \"Index\": $2,
  \"Job\": \"micro_ng\",
  \"VarzUser\": \"trafic_controller\",
  \"VarzPass\": \"c1oudc0w\",
  \"VarzPort\": 6799,
  \"NatsHosts\": [$3],
  \"NatsPort\": 4222,
  \"NatsUser\": \"nats\",
  \"NatsPass\": \"c1oudc0w\",
  \"EtcdQueryIntervalMilliseconds\": 5000,
  \"Zone\": \"$4\",
  \"LoggregatorLegacyPort\": 13456,
  \"LoggregatorDropsondePort\": 13457

  
  , \"Syslog\": \"vcap.metron_agent\"
  
}" >> /var/vcap/jobs/metron_agent/config/metron_agent.json

}

etcd="$1"
index="$2"
nats_urls="$3"
zone="$4"

editmetron "$1" "$2" "$3" "$4"
