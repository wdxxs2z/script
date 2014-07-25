#!/bin/bash

function editlogtraffic() {

echo "{
    \"Loggregators\": {$2},
    \"LoggregatorIncomingPort\": 3456,
    \"LoggregatorOutgoingPort\": 38080,
    \"IncomingPort\": 13456,
    \"OutgoingPort\": 48080,
    \"SkipCertVerify\": true,
    \"SharedSecret\": \"c1oudc0w\",
    \"Zone\": \"$1\",
    \"Host\": \"0.0.0.0\",
    \"ApiHost\": \"$3\",
    \"SystemDomain\": \"$4\",

    \"NatsHosts\": [$5],
    \"NatsPort\": 4222,
    \"NatsUser\": \"nats\",
    \"NatsPass\": \"c1oudc0w\",
    \"VarzUser\": \"trafic_controller\",
    \"VarzPass\": \"c1oudc0w\",
    \"VarzPort\": 6789
    
    , \"Syslog\": \"vcap.trafficcontroller\"
    
}" >> /var/vcap/jobs/loggregator_trafficcontroller/config/loggregator_trafficcontroller.json

}

zone="$1"
loggregator_url="$2"
apihost="$3"
sysdomain="$4"
nats_urls="$5"

editlogtraffic "$zone" "$loggregator_url" "$apihost" "$sysdomain" "$nats_urls"



