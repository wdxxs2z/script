#!/bin/bash

function editlogtraffic() {

echo "{
	\"JobName\": \"micro_ng\",
	\"JobIndex\": $1,
	\"EtcdUrls\": [$2],
	\"EtcdMaxConcurrentRequests\": 10,
    \"LoggregatorIncomingPort\": 13456,
    \"LoggregatorOutgoingPort\": 38080,
    \"OutgoingDropsondePort\": 38081,
    \"IncomingPort\": 23456,
    \"OutgoingPort\": 28080,
    \"SkipCertVerify\": true,
    \"SharedSecret\": \"c1oudc0w\",
    \"Zone\": \"$3\",
    \"Host\": \"0.0.0.0\",
    \"ApiHost\": \"$4\",
    \"SystemDomain\": \"$5\",

    \"NatsHosts\": [$6],
    \"NatsPort\": 4222,
    \"NatsUser\": \"nats\",
    \"NatsPass\": \"c1oudc0w\",
    \"VarzUser\": \"trafic_controller\",
    \"VarzPass\": \"c1oudc0w\",
    \"VarzPort\": 6789
    
    , \"Syslog\": \"vcap.trafficcontroller\"
    
}" >> /var/vcap/jobs/loggregator_trafficcontroller/config/loggregator_trafficcontroller.json

}

index="$1"
etcd_urls="$2"
zone="$3"
apihost="$4"
sysdomain="$5"
nats_urls="$6"

editlogtraffic "$index" "$etcd_urls" "$zone" "$apihost" "$sysdomain" "$nats_urls"