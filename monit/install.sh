#!/bin/bash
echo "**********************************************************"
echo "*             Install monit job                          *"
echo "**********************************************************"

if [ ! -d /var/vcap/monit/job ]; then
    mkdir -p /var/vcap/monit/job
fi

if [ ! -d /home/vcap/cf-config-script ]; then
    pushd /home/vcap/
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

if [ ! -f /var/vcap/bosh/bin/monit ]; then
    source /home/vcap/script/monit/build.sh
fi

source /home/vcap/script/monit/register.sh

#intsll component monit
COMPONENT=$1

if [ "$COMPONENT" == "cloud_controller_ng" ]
then
    cp /home/vcap/cf-config-script/"$COMPONENT"/monit /var/vcap/jobs/"$COMPONENT"/
    cp /home/vcap/cf-config-script/"$COMPONENT"/0011_micro_ng.cloud_controller_ng.monitrc /var/vcap/jobs/"$COMPONENT"/
    if [ ! -f /var/vcap/monit/job/micro_ng.$COMPONENT.monitrc ]; then
        pushd /var/vcap/jobs/"$COMPONENT"/
        cp 0011_micro_ng.cloud_controller_ng.monitrc micro_ng.$COMPONENT.monitrc
        NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}
        sed -i "s/192.168.64.142/${NISE_IP_ADDRESS}/g" micro_ng.$COMPONENT.monitrc
        ln -s /var/vcap/jobs/"$COMPONENT"/micro_ng.$COMPONENT.monitrc /var/vcap/monit/job/micro_ng.$COMPONENT.monitrc
        popd
    fi
fi

if [ "$COMPONENT" == "cloud_controller_worker" ]
then
    cp /home/vcap/cf-config-script/"$COMPONENT"/monit /var/vcap/jobs/"$COMPONENT"/
    cp /home/vcap/cf-config-script/"$COMPONENT"/0010_micro_ng.cloud_controller_worker.monitrc /var/vcap/jobs/"$COMPONENT"/
    if [ ! -f /var/vcap/monit/job/micro_ng.$COMPONENT.monitrc ]; then
        pushd /var/vcap/jobs/"$COMPONENT"/
        cp 0010_micro_ng.cloud_controller_worker.monitrc micro_ng.$COMPONENT.monitrc
        ln -s /var/vcap/jobs/"$COMPONENT"/micro_ng.$COMPONENT.monitrc /var/vcap/monit/job/micro_ng.$COMPONENT.monitrc
        popd
    fi
fi

if [ "$COMPONENT" != "cloud_controller_worker" ] && [ "$COMPONENT" != "cloud_controller_ng" ]
then
    cp /home/vcap/cf-config-script/"$COMPONENT"/monit /var/vcap/jobs/"$COMPONENT"/

    if [ ! -f /var/vcap/monit/job/micro_ng.$COMPONENT.monitrc ]; then
    pushd /var/vcap/jobs/"$COMPONENT"/
        cp monit micro_ng.$COMPONENT.monitrc
        ln -s /var/vcap/jobs/"$COMPONENT"/micro_ng.$COMPONENT.monitrc /var/vcap/monit/job/micro_ng.$COMPONENT.monitrc
    popd
    fi
fi

#useradd syslog
sudo useradd syslog
sudo usermod -a -G adm syslog

#runit
pushd /home/vcap/
wget http://smarden.org/runit/runit-2.1.2.tar.gz
tar -zxf runit-2.1.2.tar.gz
rm runit-2.1.2.tar.gz
cd admin/runit-2.1.2
sudo ./package/install
sudo cp /usr/local/bin/chpst /sbin/
popd

