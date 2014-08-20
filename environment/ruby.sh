#!/bin/bash
homeDir=/home/vcap


    if [ ! -d $homeDir/ruby ]; then
        echo "---------Make ruby env folder!----------"
	mkdir -p $homeDir/ruby
    fi

    if [ ! -f $homeDir/Downloads/ruby-1.9.3-p547.tar.gz ]; then
    	echo "---------Download ruby------------------"
	#sudo apt-get install -y libyaml-dev
	mkdir -p $homeDir/Downloads
	wget -P $homeDir/Downloads http://cache.ruby-lang.org/pub/ruby/ruby-1.9.3-p547.tar.gz
        wget -P $homeDir/Downloads http://pyyaml.org/download/libyaml/yaml-0.1.5.tar.gz
    fi

    echo "Setup Ruby 1.9.3-p547........"
    tar zxvf $homeDir/Downloads/ruby-1.9.3-p547.tar.gz -C $homeDir/Downloads
    tar zxvf $homeDir/Downloads/yaml-0.1.5.tar.gz -C $homeDir/Downloads

    pushd $homeDir/Downloads/yaml-0.1.5
    ./configure
    make
    make install  
    popd
    
    read dd

    pushd $homeDir/Downloads/ruby-1.9.3-p547
    ./configure --prefix=/home/vcap/ruby
    make && make install
    popd

    echo "Set Ruby env........."
    echo "export PATH=/home/vcap/ruby/bin:\$PATH" >> ~/.bashrc
    echo "export RUBY_PATH=/home/vcap/ruby:\$RUBY_PATH" >> ~/.bashrc
    source ~/.bashrc

    gem install bundler --no-rdoc --no-ri
    gem install rake --no-rdoc --no-ri
