#!/bin/bash

if [ ! -f /etc/lsb-release ] || \
   [ `uname -m` != "x86_64" ]; then
   echo "This libdep install will be only support ubuntu x86_64 system"
   exit 1;
fi

#git lib dep
if ! (which git); then
   sudo apt-get update
   sudo apt-get install -y git-core
fi

#baselib 
echo "If you want to setup this lib dep,please entry 'y'!"
read baselib
if [ $baselib == "y" ]; then
   sudo apt-get install -y ssh g++ gcc make cmake openssl libpq-dev jq \
libsqlite3-dev libxml2-dev libxslt-dev
fi

#importent lib
echo "This step is must be!!!!"
   sudo apt-get install -o Dpkg::Options::="--force-confnew" -f -y \
--force-yes --no-install-recommends \
build-essential libssl-dev lsof \
strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison libreadline6-dev \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb tripwire libcap2-bin \
libyaml-dev libssl1.0.0 libreadline6-dev git-daemon-run

sudo apt-get install -y libcurl3 libcurl3-gnutls libcurl4-openssl-dev zlib1g-dev libreadline6-dev

sudo apt-get -y install build-essential libreadline-dev libssl-dev zlib1g-dev git-core

#warden must lib
echo "-----------------Warden lib Dep--------------------"
sudo apt-get -y install linux-image-virtual linux-image-extra-virtual build-essential debootstrap linux-image cgroup-bin linux-virtual

#go env lib
if ! (which mercurial); then
   sudo apt-get install -y mercurial binutils build-essential bison
fi

#kernel update
sudo apt-get dist-upgrade
