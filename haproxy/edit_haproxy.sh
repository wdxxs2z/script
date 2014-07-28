#!/bin/bash

function edit_haproxy() {

echo "global
    log 127.0.0.1   syslog info
    daemon
    user vcap
    group vcap
    maxconn 64000
    spread-checks 4

defaults
    log global
    timeout connect 30000ms
    timeout client 300000ms
    timeout server 300000ms

frontend http-in
    mode http
    bind :80
    option httplog
    option forwardfor
    reqadd X-Forwarded-Proto:\ http
    default_backend http-routers


frontend https-in
    mode http
    bind :443 ssl crt /var/vcap/jobs/haproxy/config/cert.pem
    option httplog
    option forwardfor
    option http-server-close
    reqadd X-Forwarded-Proto:\ https
    default_backend http-routers

frontend ssl-in
    mode tcp
    bind :4443 ssl crt /var/vcap/jobs/haproxy/config/cert.pem
    default_backend tcp-routers


backend http-routers
    mode http
    balance roundrobin
    

    
        $1
    
    

backend tcp-routers
    mode tcp
    balance roundrobin
    

    
        $1
    
" >> /var/vcap/jobs/haproxy/config/haproxy.config
}

backend_urls="$1"

edit_haproxy "$backend_urls"
