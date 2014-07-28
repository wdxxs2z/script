#!/bin/bash
set +x

cfscriptdir=/home/vcap/cf-config-script
homedir=/home/vcap

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

UAA_CONFIG=/var/vcap/jobs/uaa/config
UAA_BIN=/var/vcap/jobs/uaa/bin

UAA_REGIST_CONFIG=$cfscriptdir/uaa/config/cf-registrar
UAA_COMPILE_DIR=/home/vcap/uaa

indexfile=/home/vcap/script/resources/uaa_index.txt
source /home/vcap/script/uaa/edit_uaa.sh

#----------------------- git init -----------------------
if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    pushd $homedir
    git clone https://github.com/cloudfoundry/cf-release 
    cd $homedir/cf-release
    git checkout c4dfff2
    git submodule update --init
    popd
fi

pushd $homedir/cf-release
cd src/uaa
git submodule update --init
popd

if [ ! -d $homedir/cf-config-script ]; then
    pushd $homedir
    git clone https://github.com/wdxxs2z/cf-config-script
    popd
fi

if [ ! -d /var/vcap/jobs/uaa ]; then
    mkdir -p $UAA_CONFIG
    mkdir -p $UAA_BIN 
fi

mkdir -p /var/vcap/packages/uaa
mkdir -p /home/vcap/uaa

BUILD_DIR=/home/vcap/build
mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/uaa

pushd $BUILD_DIR

if [ ! -d $BUILD_DIR/cf-registrar-bundle-for-identity ]; then
    cp -a $homedir/cf-release/src/cf-registrar-bundle-for-identity $BUILD_DIR
fi

if [ ! -f $BUILD_DIR/maven/apache-maven-3.1.1-bin.tar.gz ]; then
    mkdir -p $BUILD_DIR/maven/
    wget http://blob.cfblob.com/6f015bd2-aefb-4996-a9d7-1ac8c3411ad6
    mv 6f015bd2-aefb-4996-a9d7-1ac8c3411ad6 $BUILD_DIR/maven/apache-maven-3.1.1-bin.tar.gz
fi

if [ ! -f $BUILD_DIR/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz ]; then
    wget http://blob.cfblob.com/869c365a-7c65-4454-8c09-212d01fa0fb1
    mv 869c365a-7c65-4454-8c09-212d01fa0fb1 $BUILD_DIR/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz
fi

if [ ! -f $BUILD_DIR/openjdk-1.7.0_51.tar.gz ]; then
    wget http://blob.cfblob.com/67b767f3-4032-4970-8535-05dbf7c696a5
    mv 67b767f3-4032-4970-8535-05dbf7c696a5 $BUILD_DIR/openjdk-1.7.0_51.tar.gz
fi

if [ ! -f $BUILD_DIR/apache-tomcat-7.0.52.tar.gz ]; then
    wget http://blob.cfblob.com/3156c5be-fde0-43ba-917b-6222c9c6d86e
    mv 3156c5be-fde0-43ba-917b-6222c9c6d86e $BUILD_DIR/apache-tomcat-7.0.52.tar.gz
fi

if [ ! -f ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war ]; then
    wget http://blob.cfblob.com/rest/objects/4e4e78bca21e121204e4e86ee151bc050928ba58f527
    mv 4e4e78bca21e121204e4e86ee151bc050928ba58f527 ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war
fi

popd

#-------------------------- uaa prepare -----------------------------
#registrar information
cd ${BUILD_DIR}/cf-registrar-bundle-for-identity

bundle package --all

#unpack Maven
cd ${BUILD_DIR}
tar zxvf maven/apache-maven-3.1.1-bin.tar.gz
export MAVEN_HOME=${BUILD_DIR}/apache-maven-3.1.1

# Make sure we can see uname
export PATH=$PATH:/bin:/usr/bin

#unpack Java - we support Mac OS 64bit and Linux 64bit otherwise we require JAVA_HOME to point to JDK
if [ `uname` = "Darwin" ]; then
  mkdir -p java
  cd java
  tar zxvf ../uaa/openjdk-1.7.0-u40-unofficial-macosx-x86_64-bundle.tgz --exclude="._*"
  export JAVA_HOME=${BUILD_DIR}/java/Contents/Home
elif [ `uname` = "Linux" ]; then
  mkdir -p java
  cd java
  tar zxvf $BUILD_DIR/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz
  export JAVA_HOME=${BUILD_DIR}/java
else
  if [ ! -d $JAVA_HOME ]; then
    echo "JAVA_HOME properly set is required for non Linux/Darwin builds."
    exit 1
  fi	
fi

#setup Java and Maven paths
export PATH=$MAVEN_HOME/bin:$JAVA_HOME/bin:$PATH

#Maven options for building
export MAVEN_OPTS='-Xmx1g -XX:MaxPermSize=512m'

#build cloud foundry war
cd $homedir/cf-release/src/uaa
mvn clean
mvn -U -e -B package -DskipTests=true -Ddot.git.directory=/home/vcap/cf-release/src/uaa/.git
cp uaa/target/cloudfoundry-identity-uaa-*.war ${BUILD_DIR}/uaa/cloudfoundry-identity-uaa.war

#remove build resources
mvn clean

#clean up - so we don't transfer files we don't need
#cd ${BUILD_DIR}
#rm -rf apache-maven*
#rm -rf java
#rm -rf maven
#rm -rf uaa/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz
#rm -rf uaa/openjdk-1.7.0-u40-unofficial-macosx-x86_64-bundle.tgz

#--------------------------------- uaa installing.....---------------

pushd /var/vcap/packages

mkdir -p /var/vcap/packages/uaa

cd /var/vcap/packages/uaa
mkdir -p  jdk
tar zxvf $BUILD_DIR/openjdk-1.7.0_51.tar.gz -C jdk

cd /var/vcap/packages/uaa

tar zxvf $BUILD_DIR/apache-tomcat-7.0.52.tar.gz

mv apache-tomcat-7.0.52 tomcat

cd tomcat
rm -rf webapps/*
cp -a ${BUILD_DIR}/uaa/cloudfoundry-identity-uaa.war webapps/ROOT.war
cp -a ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war webapps/varz.war

cd /var/vcap/packages/uaa
cp -a ${BUILD_DIR}/cf-registrar-bundle-for-identity vcap-common
cd vcap-common
/var/vcap/packages/ruby/bin/bundle package --all
/var/vcap/packages/ruby/bin/bundle install --binstubs --deployment --local --without=development test

popd


#--------------------------etcd init ----------------------------------
source /home/vcap/script/uaa/etcdinit.sh
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

register_nats_urls=/deployment/v1/nats-server/nats_urls
register_uaa_urls=/deployment/v1/uaa-server

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

pushd /home/vcap/etcdctl

./build

popd

rm -fr /home/vcap/script/resources/db_url.txt /home/vcap/script/resources/cc_base_url.txt
rm -fr /home/vcap/script/resources/uaa_urls.txt uaasdirs.txt

etcdctl get /deployment/v1/db >> /home/vcap/script/resources/db_url.txt
etcdctl get /deployment/v1/manifest/domain >> /home/vcap/script/resources/cc_base_url.txt

rm -fr natsdirs.txt /home/vcap/script/resources/natsip.txt

etcdctl mkdir /deployment/v1/nats-server/nats_urls

etcdctl ls /deployment/v1/nats-server/nats_urls >> natsdirs.txt

while read urls
do
etcdctl get $urls >> /home/vcap/script/resources/natsip.txt
done < natsdirs.txt

if [ ! -f /home/vcap/script/resources/natsip.txt ]; then
    echo "nats not deployment...." >> error.txt
    exit 1
fi

etcdctl mkdir /deployment/v1/uaa-server
etcdctl mkdir /deployment/v1/uaa-server/uaa_urls

etcdctl ls /deployment/v1/uaa-server/uaa_urls >> uaasdirs.txt

while read uaaurls
do
etcdctl get $uaaurls >> /home/vcap/script/resources/uaa_urls.txt
done < uaasdirs.txt

# create and register index
etcdctl mkdir /deployment/v1/uaa-server/index
rm -fr uaaindexdirs.txt

# create and register uaa_urls

flag="false"
  
if [ "$NISE_IP_ADDRESS" != "" ]; then
    for j in `cat /home/vcap/script/resources/uaa_urls.txt`
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
        curl http://$etcd_endpoint:4001/v2/keys/deployment/v1/uaa-server/uaa_urls -XPOST -d value=$NISE_IP_ADDRESS
   
        #register index
        message=`curl -L http://$etcd_endpoint:4001/v2/keys/deployment/v1/uaa-server/index/0 |jq '.message' | cut -f 2 -d '"'`
        if [ "$message" == "Key not found" ]; then
            etcdctl set /deployment/v1/uaa-server/index/0 $NISE_IP_ADDRESS
            echo "0" > /home/vcap/script/resources/uaa_index.txt
        else
            etcdctl ls /deployment/v1/uaa-server/index/index >> uaaindexdirs.txt
            last=`sed -n '$=' uaaindexdirs.txt`
            new_index=`expr $last + 1`
            etcdctl set /deployment/v1/uaa-server/index/$new_index $NISE_IP_ADDRESS
            echo "$new_index" > /home/vcap/script/resources/uaa_index.txt
        fi
    fi
    if [ "$flag" == "true" ]
    then
        echo "flag is true,this is info: the ip is already regist!And other just update!"
        #keep old index
        rm -fr oldindex.txt
        etcdctl ls /deployment/v1/uaa-server/index >> oldindex.txt
        for old in `cat oldindex.txt`
        do
            old_urls=`etcdctl get $old`
            if [ "$old_urls" == "$NISE_IP_ADDRESS" ]; then
                echo "$old" |cut -f6 -d '/' > /home/vcap/script/resources/uaa_index.txt
            fi
        done    
    fi
else
    break  
fi

#------------------------- UAA config ---------------------------------
cp -a $cfscriptdir/uaa/config/* $UAA_CONFIG/
rm -fr $UAA_CONFIG/uaa.yml
rm -fr $UAA_CONFIG/cf-registrar/config.yml

pushd $UAA_CONFIG

#localhost
NISE_IP_ADDRESS=${NISE_IP_ADDRESS:-`ip addr | grep 'inet .*global' | cut -f 6 -d ' ' | cut -f1 -d '/' | head -n 1`}

#db_url
db_url=`more /home/vcap/script/resources/db_url.txt`

#nats_urls
while read line
do
echo -e "- nats://nats:c1oudc0w@$line:4222" >> lnats.txt
done < /home/vcap/script/resources/natsip.txt

nats_servers=`more lnats.txt`

#uaa_index
index=$(cat $indexfile)

#base_url
cc_base_url=`more /home/vcap/script/resources/cc_base_url.txt`

edit_uaa "$cc_base_url" "$nats_servers" "$db_url" "$NISE_IP_ADDRESS" "$index"

rm -fr lnats.txt
popd

#--------------------------------- UAA bin ---------------------------------
pushd $UAA_BIN

cp -a $cfscriptdir/uaa/bin/* $UAA_BIN/
chmod +x $UAA_BIN/*

popd

echo "uaa is already installed success!"