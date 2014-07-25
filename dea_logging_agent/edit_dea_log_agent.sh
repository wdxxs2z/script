#!/bin/bash

function edit_dea_log_agent() {

echo "{
	\"Index\": $1,
	\"LoggregatorAddress\": \"$2:3456\",
        \"SharedSecret\": \"c1oudc0w\",

	\"NatsHosts\": [$3],
  	\"NatsPort\": 4222,
  	\"NatsUser\": \"nats\",
  	\"NatsPass\": \"c1oudc0w\",
  	\"VarzUser\": \"\",
  	\"VarzPass\": \"\",
  	\"VarzPort\": 0
    
    , \"Syslog\": \"vcap.dea_logging_agent\"
    
}" >> /var/vcap/jobs/dea_logging_agent/config/dea_logging_agent.json 

}

index="$1"
logg_endpoint="$2"
nats_urls="$3"

edit_dea_log_agent() "$index" "$logg_endpoint" "$nats_urls"
