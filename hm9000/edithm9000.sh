#!/bin/bash

function edithm9000() {

echo "{
    \"heartbeat_period_in_seconds\": 10,

    \"cc_auth_user\": \"bulk_api\",
    \"cc_auth_password\": \"c1oudc0w\",
    \"cc_base_url\": \"$1\",
    \"skip_cert_verify\": true,
    \"desired_state_batch_size\": 500,
    \"fetcher_network_timeout_in_seconds\": 10,

    \"store_schema_version\": 4,
    \"store_urls\": [$2],

    \"metrics_server_port\": 0,
    \"metrics_server_user\": \"\",
    \"metrics_server_password\": \"\",

    \"log_level\": \"INFO\",

    \"nats\": [$3]
}" >> /var/vcap/jobs/hm9000/config/hm9000.json

}

cc_base_url="$1"
etcd_store_url="$2"
nats_url="$3"

edithm9000 "$1" "$2" "$3" 
