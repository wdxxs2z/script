#!/bin/bash

set -e

pushd /var/vcap/packages

if [ ! -d ruby ]; then
    mkdir -p ruby
fi

if [ ! -f /var/vcap/packages/ruby/ruby-1.9.3-p547.tar.gz ]; then
    wget http://blob.cfblob.com/82ec5a34-c6f5-46ba-8420-d927020a2a41
    mv 82ec5a34-c6f5-46ba-8420-d927020a2a41 ruby/ruby-1.9.3-p547.tar.gz
fi

if [ ! -f /var/vcap/packages/ruby/rubygems-1.8.24.tgz ]; then
    wget http://blob.cfblob.com/rest/objects/4e4e78bca41e122204e4e9863d076304fa1cc28797a9
    mv 4e4e78bca41e122204e4e9863d076304fa1cc28797a9 ruby/rubygems-1.8.24.tgz
fi

if [ ! -f /var/vcap/packages/ruby/bundler-1.2.1.gem ]; then
    wget http://blob.cfblob.com/rest/objects/4e4e78bca31e121204e4e86ee39692050a16252f052f
    mv 4e4e78bca31e121204e4e86ee39692050a16252f052f ruby/bundler-1.2.1.gem
fi

if [ ! -f /var/vcap/packages/ruby/yaml-0.1.6.tar.gz ]; then
    wget http://blob.cfblob.com/3b33cc37-7522-44cd-a068-ab61c5df746e
    mv 3b33cc37-7522-44cd-a068-ab61c5df746e ruby/yaml-0.1.6.tar.gz
fi

popd

pushd /var/vcap/packages

BOSH_INSTALL_TARGET=/var/vcap/packages/ruby

# We grab the latest versions that are in the directory
RUBY_VERSION=`ls -r ruby/ruby-* | sed 's/ruby\/ruby-\(.*\)\.tar\.gz/\1/' | head -1`
RUBYGEMS_VERSION=`ls -r ruby/rubygems-* | sed 's/ruby\/rubygems-\(.*\)\.tgz/\1/' | head -1`
BUNDLER_VERSION=`ls -r ruby/bundler-* | sed 's/ruby\/bundler-\(.*\)\.gem/\1/' | head -1`
LIBYAML_VERSION=`ls -r ruby/yaml-* | sed 's/ruby\/yaml-\(.*\)\.tar\.gz/\1/' | head -1`

# Install libyaml >= 0.1.5 to fix http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2013-6393
tar xzf ruby/yaml-${LIBYAML_VERSION}.tar.gz
(
  set -e
  cd yaml-${LIBYAML_VERSION}/
  ./configure --prefix=${BOSH_INSTALL_TARGET}
  make -j 3   # Use 3 CPUs, which is 1.5 x 2 (the normal number of compile CPUs)
  make install
  sudo ldconfig
)

tar xzf ruby/ruby-${RUBY_VERSION}.tar.gz
(
  set -e
  cd ruby-${RUBY_VERSION}
  ./configure --prefix=${BOSH_INSTALL_TARGET} --disable-install-doc --with-opt-dir=/var/vcap/packages/ruby/lib
  make
  make install
)

tar zxvf ruby/rubygems-${RUBYGEMS_VERSION}.tgz
(
  set -e
  cd rubygems-${RUBYGEMS_VERSION}

  ${BOSH_INSTALL_TARGET}/bin/ruby setup.rb

  if [[ $? != 0 ]] ; then
    echo "Cannot install rubygems"
    exit 1
  fi
)

${BOSH_INSTALL_TARGET}/bin/gem install ruby/bundler-${BUNDLER_VERSION}.gem --no-ri --no-rdoc
${BOSH_INSTALL_TARGET}/bin/gem install rake -v 0.9.2.2 --no-rdoc --no-ri

popd
