#!/bin/bash

if [ ! -f /etc/issue ]
then
  echo "/etc/issue doesn't exist; cannot determine distribution"
  exit 1
fi

if grep -q -i ubuntu /etc/issue
then
    echo "ubuntu libdeps install or update."
    
    #git lib dep
    if ! (which git); then
        sudo apt-get update
        sudo apt-get install -y git-core
    fi

    #baselib 
    sudo apt-get install -y ssh g++ gcc make cmake openssl libpq-dev jq libsqlite3-dev libxml2-dev libxslt-dev

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

fi

if grep -q -i centos /etc/issue
then
    echo "centos system libdeps install or update."
    
    sudo yum -y install perl-ExtUtils-MakeMaker perl-ExtUtils-CBuilder perl-Time-HiRes nc 
    sudo yum -y groupinstall "Development Tools"
    sudo yum -y install quota
    sudo yum -y install glibc-static
    sudo yum -y install gcc make cmake gcc-c++ autoconf automake bzip2-devel zlib-devel ncurses-devel libjpeg-devel libpng-devel libtiff-devel freetype-devel \
    pam-devel openssl-devel libxml2-devel gettext-devel pcre-devel git-daemon libcurl mysql-server mysql-devel postgresql-devel

fi
