#!/bin/bash

set +x

if [ ! -d /var/vcap/packages/common ]; then
    mkdir -p /var/vcap/packages/common
fi

cp -a /home/vcap/cf-release/src/common/* /var/vcap/packages/common/
