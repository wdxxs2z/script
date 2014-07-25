#!/bin/bash

function edit_uaa() {

echo -e "---



name: uaa

database:
  url: jdbc:postgresql://$3:5524/uaadb
  username: uaaadmin
  password: \"c1oudc0w\"

spring_profiles: postgresql

logging:
  config: /var/vcap/jobs/uaa/config/log4j.properties


jwt:
  token:
    signing-key: |
        -----BEGIN RSA PRIVATE KEY-----
        MIICXAIBAAKBgQDHFr+KICms+tuT1OXJwhCUmR2dKVy7psa8xzElSyzqx7oJyfJ1
        JZyOzToj9T5SfTIq396agbHJWVfYphNahvZ/7uMXqHxf+ZH9BL1gk9Y6kCnbM5R6
        0gfwjyW1/dQPjOzn9N394zd2FJoFHwdq9Qs0wBugspULZVNRxq7veq/fzwIDAQAB
        AoGBAJ8dRTQFhIllbHx4GLbpTQsWXJ6w4hZvskJKCLM/o8R4n+0W45pQ1xEiYKdA
        Z/DRcnjltylRImBD8XuLL8iYOQSZXNMb1h3g5/UGbUXLmCgQLOUUlnYt34QOQm+0
        KvUqfMSFBbKMsYBAoQmNdTHBaz3dZa8ON9hh/f5TT8u0OWNRAkEA5opzsIXv+52J
        duc1VGyX3SwlxiE2dStW8wZqGiuLH142n6MKnkLU4ctNLiclw6BZePXFZYIK+AkE
        xQ+k16je5QJBAN0TIKMPWIbbHVr5rkdUqOyezlFFWYOwnMmw/BKa1d3zp54VP/P8
        +5aQ2d4sMoKEOfdWH7UqMe3FszfYFvSu5KMCQFMYeFaaEEP7Jn8rGzfQ5HQd44ek
        lQJqmq6CE2BXbY/i34FuvPcKU70HEEygY6Y9d8J3o6zQ0K9SYNu+pcXt4lkCQA3h
        jJQQe5uEGJTExqed7jllQ0khFJzLMx0K6tj0NeeIzAaGCQz13oo2sCdeGRHO4aDh
        HH6Qlq/6UOV5wP8+GAcCQFgRCcB+hrje8hfEEefHcFpyKH+5g1Eu1k0mLrxK2zd+
        4SlotYRHgPCEubokb2S1zfZDWIXW3HmggnGgM949TlY=
        -----END RSA PRIVATE KEY-----
        
    verification-key: |
        -----BEGIN PUBLIC KEY-----
        MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDHFr+KICms+tuT1OXJwhCUmR2d
        KVy7psa8xzElSyzqx7oJyfJ1JZyOzToj9T5SfTIq396agbHJWVfYphNahvZ/7uMX
        qHxf+ZH9BL1gk9Y6kCnbM5R60gfwjyW1/dQPjOzn9N394zd2FJoFHwdq9Qs0wBug
        spULZVNRxq7veq/fzwIDAQAB
        -----END PUBLIC KEY-----
        




issuer.uri: https://uaa.$1.xip.io

oauth:
  
  authorize:
    ssl: true
  
  client:
  
    autoapprove:
      - cf
      - login
      - developer_console
      - support-signon
  
  clients:



    admin:
      authorized-grant-types: client_credentials
      authorities: clients.read,clients.write,clients.secret,uaa.admin,scim.read,password.write
      id: admin
      secret: \"c1oudc0w\"


    cloud_controller:
      authorized-grant-types: client_credentials
      authorities: scim.read,scim.write,password.write
      id: cloud_controller
      secret: \"c1oudc0w\"
      access-token-validity: 604800


    cf:
      id: cf
      override: true
      authorized-grant-types: implicit,password,refresh_token
      scope: cloud_controller.read,cloud_controller.write,openid,password.write,cloud_controller.admin,scim.read,scim.write
      authorities: uaa.none
      access-token-validity: 600
      refresh-token-validity: 2592000


    login:
      id: login
      override: true
      secret: \"\"
      authorized-grant-types: authorization_code,client_credentials,refresh_token
      authorities: oauth.login
      scope: openid,oauth.approvals
      redirect-uri: https://login.$1.xip.io


scim:
  userids_enabled: false


  user.override: true

  users: 
    - admin|c1oudc0w|scim.write,scim.read,openid,cloud_controller.admin



" >> /var/vcap/jobs/uaa/config/uaa.yml

echo -e "---
logging:
  file: /var/vcap/sys/log/uaa/cf-registrar.log
  
  level: info

message_bus_servers:

  $2


uri:
  - uaa.$1.xip.io
host: $4
index: $5
port: 8080
tags:
  component: uaa
varz:
  file: /var/vcap/jobs/uaa/config/varz.yml
" >> /var/vcap/jobs/uaa/config/cf-registrar/config.yml
}

cc_base_url="$1"
nats_urls="$2"
db_url="$3"
localhost="$4"
uaa_index="$5"

edit_uaa "cc_base_url" "nats_urls" "db_url" "localhost" "uaa_index"
