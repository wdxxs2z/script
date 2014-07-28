#!/bin/bash

function editdea_ng() {

    echo -e "---
nats_servers:

  $1


dea_ruby: /usr/bin/ruby

pid_filename: /var/vcap/sys/run/dea_next/dea_next.pid

base_dir: /var/vcap/data/dea_next

warden_socket: /var/vcap/data/warden/warden.sock

evacuation_bail_out_time_in_seconds: 115
default_health_check_timeout: 60
crash_lifetime_secs: 3600

directory_server:
  protocol: 'https'
  v1_port: 12345
  v2_port: 34567
  file_api_port: 23456
  streaming_timeout: 
  logging:
    file: /var/vcap/sys/log/dea_next/dir_server.log
    
    syslog: vcap.directory_server
    
    level: debug

domain: $2.xip.io

logging:
  file: /var/vcap/sys/log/dea_next/dea_next.log
  level: debug
  


loggregator:
  router: $3:3456
  shared_secret: c1oudc0w


index: $4

intervals:
  heartbeat: 10
  advertise: 5

resources:
  memory_mb: 8000
  memory_overcommit_factor: 1
  disk_mb: 32000
  disk_overcommit_factor: 1

bind_mounts:
- src_path: /var/vcap/packages/buildpack_cache

staging:
  enabled: true
  max_staging_duration: 900
  memory_limit_mb: 1024
  disk_limit_mb: 4096
  cpu_limit_shares: 512
  disk_inode_limit: 200000
  environment:
    BUILDPACK_CACHE: \"/var/vcap/packages/buildpack_cache\"

instance:
  memory_to_cpu_share_ratio: 8
  min_cpu_share_limit: 1
  max_cpu_share_limit: 256
  disk_inode_limit: 200000

stacks: [\"lucid64\"]
placement_properties:
  zone: $5
" >> /var/vcap/jobs/dea_next/config/dea.yml
}

nats_urls="$1"
domain="$2"
loggregator_endpoint="$3"
index="$4"
zone="$5"

editdea_ng "$nats_urls" "$domain" "$loggregator_endpoint" "$index" "$zone"
