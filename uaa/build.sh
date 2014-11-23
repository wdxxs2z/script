#!/bin/bash

echo "**********************************************"
echo "*           build uaa                        *"
echo "**********************************************"

homedir=/home/vcap

export PATH=/home/vcap/etcdctl/bin:$PATH

source /home/vcap/script/util/etcdinit.sh > peers.txt
while read line
do
    export ETCDCTL_PEERS=http://$line:4001
done < peers.txt
rm -fr peers.txt

RESOURCE_URL=`etcdctl get /deployment/v1/manifest/resourceurl`
#----------------------- git init -----------------------
if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

pushd $homedir/cf-release
cd src/uaa
git submodule update --init
popd

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
    wget http://$RESOURCE_URL/packages/maven/apache-maven-3.1.1-bin.tar.gz
    mv apache-maven-3.1.1-bin.tar.gz $BUILD_DIR/maven/apache-maven-3.1.1-bin.tar.gz
fi

if [ ! -f $BUILD_DIR/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz ]; then
    wget http://$RESOURCE_URL/packages/uaa/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz
fi

if [ ! -f $BUILD_DIR/openjdk-1.7.0_51.tar.gz ]; then
    wget http://$RESOURCE_URL/packages/uaa/openjdk-1.7.0_51.tar.gz
fi

if [ ! -f $BUILD_DIR/apache-tomcat-7.0.52.tar.gz ]; then
    wget http://$RESOURCE_URL/packages/uaa/apache-tomcat-7.0.52.tar.gz
fi

if [ ! -f ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war ]; then
    wget http://$RESOURCE_URL/packages/uaa/cloudfoundry-identity-varz-1.0.2.war
    mv cloudfoundry-identity-varz-1.0.2.war ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war
fi

popd

#-------------------------- uaa prepare -----------------------------
#registrar information
#unpack Maven
cd ${BUILD_DIR}
tar zxf maven/apache-maven-3.1.1-bin.tar.gz
export MAVEN_HOME=${BUILD_DIR}/apache-maven-3.1.1

# Make sure we can see uname
export PATH=$PATH:/bin:/usr/bin

#unpack Java - we support Mac OS 64bit and Linux 64bit otherwise we require JAVA_HOME to point to JDK
if [ `uname` = "Darwin" ]; then
  mkdir -p java
  cd java
  tar -zxf ../uaa/openjdk-1.7.0-u40-unofficial-macosx-x86_64-bundle.tgz --exclude="._*"
  export JAVA_HOME=${BUILD_DIR}/java/Contents/Home
elif [ `uname` = "Linux" ]; then
  mkdir -p java
  cd java
  tar -zxf $BUILD_DIR/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz
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
#mvn clean
./gradlew assemble
#mvn -U -e -B package -DskipTests=true -Ddot.git.directory=/home/vcap/cf-release/src/uaa/.git
#cp uaa/target/cloudfoundry-identity-uaa-*.war ${BUILD_DIR}/uaa/cloudfoundry-identity-uaa.war
cp uaa/build/libs/cloudfoundry-identity-uaa-*.war ${BUILD_DIR}/uaa/cloudfoundry-identity-uaa.war

#remove build resources
#mvn clean
./gradlew clean

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
rm -fr /var/vcap/packages/uaa/*

mkdir -p  jdk
tar -zxf $BUILD_DIR/openjdk-1.7.0_51.tar.gz -C jdk

cd /var/vcap/packages/uaa

tar -zxf $BUILD_DIR/apache-tomcat-7.0.52.tar.gz

mv apache-tomcat-7.0.52 tomcat

cd tomcat
rm -rf webapps/*
cp -a ${BUILD_DIR}/uaa/cloudfoundry-identity-uaa.war webapps/ROOT.war
cp -a ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war webapps/varz.war

export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH
cd /var/vcap/packages/uaa
rm -fr /var/vcap/packages/uaa/vcap-common
wget http://$RESOURCE_URL/packages/uaa/vcap-common.tar.gz
tar -zxvf vcap-common.tar.gz

pushd /var/vcap/packages

mkdir -p /var/vcap/packages/common/

cp -a /home/vcap/cf-release/src/common/* /var/vcap/packages/common/

mkdir -p /var/vcap/packages/syslog_aggregator

#ubuntu and centos
if grep -q -i ubuntu /etc/issue
then
    cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/
fi

if grep -q -i centos /etc/issue
then
    cp -a $homedir/cf-release/src/syslog_aggregator/* /var/vcap/packages/syslog_aggregator/
    sed -i "s/\/usr\/sbin/\/sbin/g" /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh 
fi

tar -zcf uaa.tar.gz uaa common syslog_aggregator

curl -F "action=/upload/build" -F "uploadfile=@uaa.tar.gz" http://$RESOURCE_URL/upload/build

rm -fr uaa.tar.gz
popd

popd

echo "UAA build success!!"

