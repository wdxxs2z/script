#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

etcd_endpoint=""
last=`sed -n '$=' /home/vcap/script/deployment.etcd`
j=1
exec 3</home/vcap/script/deployment.etcd
while read line <&3
do
   if [ "$j" -eq "$last" ]
   then
       echo -e "\"http://$line:4001\"" >> dep_etcd.txt
       error=`nc -w 1 $line 4001 && echo true || echo false`
       if [ "$error" == "false" ]; then
           echo "Some etcd is bbbb...:$line" >> manifest.log
       else
	   leader=`curl -L http://$line:4001/v2/stats/leader | jq '.leader' | cut -f 2 -d '"'`
           etcd_endpoint=`curl -L http://$line:7001/v2/admin/machines/$leader | jq '.clientURL' | cut -f 2 -d ':' | cut -f 3 -d '/'`
       fi
   else
       echo -e "\"http://$line:4001\",\c" >> dep_etcd.txt
       error=`nc -w 1 $line 4001 && echo true || echo false`
       if [ "$error" == "false" ]; then
           echo "Some etcd is bbbb...:$line" >> manifest.log
       else
           leader=`curl -L http://$line:4001/v2/stats/leader | jq '.leader' | cut -f 2 -d '"'`
           etcd_endpoint=`curl -L http://$line:7001/v2/admin/machines/$leader | jq '.clientURL' | cut -f 2 -d ':' | cut -f 3 -d '/'`
       fi
       ((j++)) 
   fi
done < /home/vcap/script/deployment.etcd

if [ "$etcd_endpoint" == "" ]; then
    echo "etcd_endpoint is not found...please check your etcd servers" >> manifest.log
    exit 1
fi

ETCDCTL_PEERS=`more dep_etcd.txt`
echo $ETCDCTL_PEERS
rm -fr dep_etcd.txt

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

#-------------------- etcdctl install -----------------------

pushd /home/vcap/etcdctl

./build

popd

#--------------------- mainfest init ------------------------
domain=`more /home/vcap/script/mainfest |grep domain | cut -f 2 -d ' '`

etcdctl set /deployment/v1/manifest/domain $domain

echo $etcd_endpoint
#--------------------- zone init ----------------------------
rm -fr zonedirs.txt zonetarget.txt
zones=`more /home/vcap/script/mainfest |grep zone`

etcdctl mkdir /deployment/v1/manifest/zone

etcdctl ls /deployment/v1/manifest/zone >> zonedirs.txt

for u in `more zonedirs.txt`
do
    etcdctl get $u >> zonetarget.txt
done

flag="false"
k=2
while((1==1))
do
    split=`echo $zones |cut -d " " -f$k`
    if [ "$split" != "" ]; then
    for m in `cat zonetarget.txt`
    do
    if [ "$split" == "$m" ]
    then
        echo "the:$split is exits!"
        flag="true"
    fi
    done
    if [ "$flag" == "false" ]
    then
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/manifest/zone -XPOST -d value=$split
    fi 
    ((k++))
    else
        break
    fi
done

#--------------------- etcdstore init -----------------------
rm -fr storedirs.txt storeurls.txt

etcds=`more /home/vcap/script/mainfest |grep etcd`

etcdctl mkdir /deployment/v1/manifest/etcdstore

etcdctl ls /deployment/v1/manifest/etcdstore >> storedirs.txt

while read urls
do
etcdctl get $urls >> storeurls.txt
done < storedirs.txt

if [ ! -f storeurls.txt ]; then
    touch storeurls.txt
fi

storeurls=`more storeurls.txt`

flag="false"
i=2
while((1==1))  
do  
    split=`echo $etcds |cut -d " " -f$i`  
    if [ "$split" != "" ]; then
    for j in `cat storeurls.txt`
    do
    if [ "$split" == "$j" ]
    then
        echo "the ip:$split is exits!"
        flag="true"
    fi
    done
    if [ "$flag" == "false" ]
    then
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/manifest/etcdstore -XPOST -d value=$split
    fi 
    ((i++))
    else
        break  
    fi  
done


rm -fr storedirs.txt storeurls.txt

