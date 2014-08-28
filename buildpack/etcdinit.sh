#!/bin/bash

#----------------- etcdctl init ----------------------
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

echo $etcd_endpoint

if [ "$etcd_endpoint" == "" ]; then
    echo "etcd_endpoint is not found...please check your etcd servers" >> manifest.log
    exit 1
fi

ETCDCTL_PEERS=`more dep_etcd.txt`
rm -fr dep_etcd.txt
