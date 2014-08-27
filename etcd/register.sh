#!/bin/bash

ETCD_CONFIG=/var/vcap/jobs/etcd/config
ETCD_BIN=/var/vcap/jobs/etcd/bin
cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap
indexfile=/home/vcap/script/resources/etcdstore_index.txt

source /home/vcap/script/etcd/etcdinit.sh
source /home/vcap/script/etcd/editetcd.sh
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

if [ ! -d $ETCD_CONFIG ]; then
    mkdir -p $ETCD_CONFIG
fi

if [ ! -d $ETCD_BIN ]; then
    mkdir -p $ETCD_BIN
fi

register_etcd_dir=/deployment/v1/manifest/etcdstore

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

pushd /home/vcap/etcdctl

./build

popd

source /home/vcap/script/etcd/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt

rm -fr peers.txt

etcdctl mkdir $register_etcd_dir
etcdctl mkdir /deployment/v1/manifest/etcdindex

pushd $ETCD_CONFIG

cp -a $cfscriptdir/etcd/config/syslog_forwarder.conf $ETCD_CONFIG

etcdctl ls $register_etcd_dir >> etcddirs.txt

while read urls
do
etcdctl get $urls >> etcdurls.txt
done < etcddirs.txt

# create and register uaa_urls

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat etcdurls.txt`
    do
    if [ "$NISE_IP_ADDRESS" == "$j" ]
    then
        echo "the ip:$NISE_IP_ADDRESS is exits!"
        flag="true"
    fi
    done
    if [ "$flag" == "false" ]
    then
        echo $etcd_endpoint
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/manifest/etcdstore -XPOST -d value=$NISE_IP_ADDRESS

        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/manifest/etcdindex/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/manifest/etcdindex/0 $NISE_IP_ADDRESS
            echo "0" > $indexfile
        else
            rm -fr etcdindexdirs.txt
            etcdctl ls /deployment/v1/manifest/etcdindex >> etcdindexdirs.txt
            last=`sed -n '$=' etcdindexdirs.txt`
            new_index=$last
            etcdctl set /deployment/v1/manifest/etcdindex/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > $indexfile
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/manifest/etcdindex >> oldindex.txt
        for old in `cat oldindex.txt`
        do
            old_urls=`etcdctl get $old`
            if [ "$old_urls" == "$NISE_IP_ADDRESS" ]; then
                echo "$old" |cut -f6 -d '/' > $indexfile
            fi
        done       
    fi
else
    break  
fi

#peers
rm -fr etcdurl.txt etcdstore.txt etcddir.txt
etcdctl ls $register_etcd_dir >> etcddir.txt
while read url
do
etcdctl get $url >> etcdurl.txt
done < etcddir.txt

lastnumber=`sed -n '$=' etcdurl.txt`
firstetcd=`sed -n '1p' etcdurl.txt`

peers=""

if [ "$lastnumber" -gt 1 ]; then
    if [ "$firstetcd" != "$NISE_IP_ADDRESS" ]; then
        echo -e "-peers=\c" >> etcdstore.txt
        j=1
        while read line
        do
            if [ "$line" == "$NISE_IP_ADDRESS" ]; then
                let j++
                continue   
            elif [ "$j" -ge "$lastnumber" ]; then
                echo -e "$line:7001 " >> etcdstore.txt
                break
            else
                #logic
                echo -e "$line:7001,\c" >> etcdstore.txt
                let j++
            fi
        done < etcdurl.txt
    else
        echo -e "$peers" >> etcdstore.txt
    fi
else
    echo -e "$peers" >> etcdstore.txt
fi

endtail=`tail -c1 etcdstore.txt`
if [ "$endtail" == "," ]; then
    sed -i '$s/.$//' etcdstore.txt
    echo -e " \c" >> etcdstore.txt
fi

#index
index=$(cat $indexfile)

#peers
peer=`more etcdstore.txt`

rm -fr /var/vcap/jobs/etcd/bin/etcd_ctl
editetcd "$NISE_IP_ADDRESS" "$index" "$peer"
chmod +x /var/vcap/jobs/etcd/bin/etcd_ctl

rm -fr etcdindexdirs.txt oldindex.txt etcdurls.txt etcdindexdirs.txt etcdurl.txt etcdstore.txt etcddir.txt etcddirs.txt
popd

