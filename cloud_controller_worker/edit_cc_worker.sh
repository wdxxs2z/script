#!/bin/bash

function edit_cc_worker() {

echo -e "---
#Actually NGX host and port
local_route: $1
external_port: 9022

pid_filename: /this/isnt/used/by/the/worker
development_mode: false

message_bus_servers:

  $2


external_protocol: http
external_domain:
  - api.$4.xip.io

system_domain_organization: DevBox
system_domain: $4.xip.io
app_domains: [ $4.xip.io ]

jobs:
  global:
    timeout_in_seconds: 14400
  
  
  
  
  
  
  
  

app_events:
  cutoff_age_in_days: 31

app_usage_events:
  cutoff_age_in_days: 31

audit_events:
  cutoff_age_in_days: 31

billing_event_writing_enabled: true

default_app_memory: 1024
default_app_disk_in_mb: 1024
maximum_app_disk_in_mb: 2048

request_timeout_in_seconds: 300

cc_partition: default

bulk_api:
  auth_user: bulk_api
  auth_password: \"c1oudc0w\"

nginx:
  use_nginx: true
  instance_socket: \"/var/vcap/sys/run/cloud_controller_ng/cloud_controller.sock\"

index: $3
name: micro_ng

info:
  name: vcap
  build: \"2222\"
  version: 2
  support_address: http://support.cloudfoundry.com
  description: Cloud Foundry sponsored by Pivotal


directories:
 tmpdir: /var/vcap/data/cloud_controller_ng/tmp


logging:
  file: /var/vcap/sys/log/cloud_controller_worker/cloud_controller_worker.log
  
  level: debug2
  max_retries: 1


loggregator:
  router: $5:3456
  shared_secret: c1oudc0w
  url: wss://loggregator.$4.xip.io:443




db: &db
  database: postgres://ccadmin:c1oudc0w@$6:5524/ccdb
  max_connections: 25
  pool_timeout: 10
  log_level: debug2




uaa:
  url: https://uaa.$4.xip.io
  resource_id: cloud_controller,cloud_controller_service_permissions
  
  verification_key: |
      -----BEGIN PUBLIC KEY-----
      MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDHFr+KICms+tuT1OXJwhCUmR2d
      KVy7psa8xzElSyzqx7oJyfJ1JZyOzToj9T5SfTIq396agbHJWVfYphNahvZ/7uMX
      qHxf+ZH9BL1gk9Y6kCnbM5R60gfwjyW1/dQPjOzn9N394zd2FJoFHwdq9Qs0wBug
      spULZVNRxq7veq/fzwIDAQAB
      -----END PUBLIC KEY-----
      

# App staging parameters
staging:
  timeout_in_seconds: 900
  minimum_staging_memory_mb: 1024
  minimum_staging_disk_mb: 4096
  auth:
    user: uploaduser
    password: \"c1oudc0w\"

maximum_health_check_timeout: 180

runtimes_file: /var/vcap/jobs/cloud_controller_ng/config/runtimes.yml
stacks_file: /var/vcap/jobs/cloud_controller_worker/config/stacks.yml

quota_definitions:
  
  default:
    memory_limit: 10240
    total_services: 100
    non_basic_services_allowed: true
    total_routes: 1000
    trial_db_allowed: true
  

default_quota_definition: default

resource_pool:
  minimum_size: 65536
  maximum_size: 536870912
  resource_directory_key: cc-resources
  
  cdn:
    uri: 
    key_pair_id: 
    private_key: \"\"
  
  fog_connection: {\"provider\":\"Local\",\"local_root\":\"/var/vcap/nfs/shared\"}

packages:
  app_package_directory_key: cc-packages
  max_package_size: 1073741824
  
  cdn:
    uri: 
    key_pair_id: 
    private_key: \"\"
  
  fog_connection: {\"provider\":\"Local\",\"local_root\":\"/var/vcap/nfs/shared\"}

droplets:
  droplet_directory_key: cc-droplets
  
  cdn:
    uri: 
    key_pair_id: 
    private_key: \"\"
  
  fog_connection: {\"provider\":\"Local\",\"local_root\":\"/var/vcap/nfs/shared\"}

buildpacks:
  buildpack_directory_key: cc-buildpacks
  
  cdn:
    uri: 
    key_pair_id: 
    private_key: \"\"
  
  fog_connection: {\"provider\":\"Local\",\"local_root\":\"/var/vcap/nfs/shared\"}

db_encryption_key: c1oudc0w

tasks_disabled: false
flapping_crash_count_threshold: 3

disable_custom_buildpacks: false

broker_client_timeout_seconds: 60

renderer:
  max_results_per_page: 100
  default_results_per_page: 50
  max_inline_relations_depth: 2



diego: false


skip_cert_verify: true


app_bits_upload_grace_period_in_seconds: 1200

security_group_definitions: [{\"name\":\"public_networks\",\"rules\":[{\"protocol\":\"all\",\"destination\":\"0.0.0.0-9.255.255.255\"},{\"protocol\":\"all\",\"destination\":\"11.0.0.0-169.253.255.255\"},{\"protocol\":\"all\",\"destination\":\"169.255.0.0-172.15.255.255\"},{\"protocol\":\"all\",\"destination\":\"172.32.0.0-192.167.255.255\"},{\"protocol\":\"all\",\"destination\":\"192.169.0.0-255.255.255.255\"}]},{\"name\":\"private_networks\",\"rules\":[{\"protocol\":\"all\",\"destination\":\"10.0.0.0-10.255.255.255\"},{\"protocol\":\"all\",\"destination\":\"172.16.0.0-172.31.255.255\"},{\"protocol\":\"all\",\"destination\":\"192.168.0.0-192.168.255.255\"}]},{\"name\":\"dns\",\"rules\":[{\"protocol\":\"tcp\",\"destination\":\"0.0.0.0/0\",\"ports\":\"53\"},{\"protocol\":\"udp\",\"destination\":\"0.0.0.0/0\",\"ports\":\"53\"}]}]
default_running_security_groups: [\"public_networks\",\"private_networks\",\"dns\"]
default_staging_security_groups: [\"public_networks\",\"private_networks\",\"dns\"]

" >> /var/vcap/jobs/cloud_controller_worker/config/cloud_controller_ng.yml
}

local_host="$1"
nats_urls="$2"
index="$3"
base_url="$4"
log_endpoint_url="$5"
db_url="$6"

edit_cc_worker "$1" "$2" "$3" "$4" "$5" "$6"

