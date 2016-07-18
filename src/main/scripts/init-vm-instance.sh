#!/bin/bash

function init_opt_boot
{
  gcsfuse mesos-shared /opt/shared
  chmod 644 /opt/shared
}

function install_opt_software
{
  echo "Not installed opt software, proceed install..."
  echo "INSTALL: mesos repo"
  apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
  DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
  CODENAME=$(lsb_release -cs)
  echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | tee /etc/apt/sources.list.d/mesosphere.list

  echo "INSTALL: Java 8 from Oracle's PPA"
  add-apt-repository -y ppa:webupd8team/java
  apt-get update -y

  # install oracle-java8 package without prompt
  echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
  echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections

  apt-get install -y oracle-java8-installer oracle-java8-set-default

  echo "INSTALL: gcsfuse - optional, using google storage to share installation packages."
  export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
  echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | tee /etc/apt/sources.list.d/gcsfuse.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  apt-get update -y
  apt-get install -y gcsfuse
  mkdir -p /opt/shared

  echo "installed opt software done." > /root/opt-installed
  echo `date` >> /root/opt-installed
}

function install_opt_mesos_master
{
  echo "INSTALL: for master, install mesosphere"
  apt-get install -y mesosphere
}

function install_opt_mesos_slave
{
  echo "INSTALL: for slave, install mesos"
  apt-get install -y mesos
}

function install_opt_smack
{
  # cassandra
  mkdir -p /opt/cassandra
  cp /opt/shared/apache-cassandra-3.0.2-bin.tar.gz /opt/cassandra/
  cd /opt/cassandra/
  tar zxvf apache-cassandra-3.0.2-bin.tar.gz 
  ln -s /opt/cassandra/apache-cassandra-3.0.2 /opt/cassandra/current
  echo 'export CASSANDRA_HOME="/opt/cassandra/current"' >> /etc/profile.d/cassandra.sh
  echo 'export PATH="$PATH:$CASSANDRA_HOME/bin"' >> /etc/profile.d/cassandra.sh
  chmod 755 /etc/profile.d/cassandra.sh

  # scala
  mkdir -p /opt/scala
  cp /opt/shared/scala-2.11.7.tgz /opt/scala/
  cd /opt/scala/
  tar zxvf scala-2.11.7.tgz
  ln -s /opt/scala/scala-2.11.7 /opt/scala/current
  echo 'export SCALA_HOME="/opt/scala/current"' >> /etc/profile.d/scala.sh
  echo 'export PATH="$PATH:$SCALA_HOME/bin"' >> /etc/profile.d/scala.sh
  chmod 755 /etc/profile.d/scala.sh

  # sbt
  mkdir -p /opt/sbt
  cp /opt/shared/sbt-0.13.9.tgz /opt/sbt/
  cd /opt/sbt/
  tar zxvf sbt-0.13.9.tgz
  mv /opt/sbt/sbt /opt/sbt/sbt-0.13.9
  ln -s /opt/sbt/sbt-0.13.9 /opt/sbt/current
  echo 'export SBT_HOME="/opt/sbt/current"' >> /etc/profile.d/scala.sh
  echo 'export PATH="$PATH:$SBT_HOME/bin"' >> /etc/profile.d/scala.sh
  # trigger sbt downloading
  # /opt/sbt/current/bin/sbt about
}

function install_opt_mesosdns
{
  mkdir -p /opt/mesos-dns
  cp /opt/shared/mesos-dns-v0.5.1-linux-amd64 /opt/mesos-dns/
  chmod 755 /opt/mesos-dns/mesos-dns-v0.5.1-linux-amd64
  ln -s /opt/mesos-dns/mesos-dns-v0.5.1-linux-amd64 /opt/mesos-dns/mesos-dns
  cp /opt/shared/mesos-dns-config.json /opt/mesos-dns/
}

function configure_zookeeper
{
  echo ${HOSTNAME##*-} > /etc/zookeeper/conf/myid
  echo "server.1=mesos-master-1:2888:3888" >> /etc/zookeeper/conf/zoo.cfg
  echo "server.2=mesos-master-2:2888:3888" >> /etc/zookeeper/conf/zoo.cfg
  echo "server.3=mesos-master-3:2888:3888" >> /etc/zookeeper/conf/zoo.cfg
}

function configure_mesos_master
{
  echo "zk://mesos-master-1:2181,mesos-master-2:2181,mesos-master-3:2181/mesos" > /etc/mesos/zk
  
  # mesos-master
  echo 2 > /etc/mesos-master/quorum
  echo $HOSTNAME | tee /etc/mesos-master/hostname
  ifconfig eth0 | awk '/inet addr/{print substr($2,6)}' | tee /etc/mesos-master/ip
  
  # mesos-marathon
  mkdir -p /etc/marathon/conf
  echo $HOSTNAME | tee /etc/marathon/conf/hostname
  echo "zk://mesos-master-1:2181,mesos-master-2:2181,mesos-master-3:2181/mesos" | tee /etc/marathon/conf/master
  echo "zk://mesos-master-1:2181,mesos-master-2:2181,mesos-master-3:2181/marathon" | tee /etc/marathon/conf/zk
  
  # set boot service
  echo manual | sudo tee /etc/init/mesos-slave.override
  restart zookeeper
  start mesos-master
  start marathon
}

function configure_mesos_slave
{
  
  stop zookeeper
  echo manual | tee /etc/init/zookeeper.override
  stop mesos-master
  echo manual | tee /etc/init/mesos-master.override
  
  echo "zk://mesos-master-1:2181,mesos-master-2:2181,mesos-master-3:2181/mesos" > /etc/mesos/zk
  ifconfig eth0 | awk '/inet addr/{print substr($2,6)}' | tee /etc/mesos-slave/ip
  echo $HOSTNAME | tee /etc/mesos-slave/hostname
  
  start mesos-slave
}

if [ -f "/root/opt-installed" ]; then
  echo "installed opt software."
  init_opt_boot
elif [[ $HOSTNAME == *"master"* ]]; then
  echo "install for role:master"
  install_opt_software
  install_opt_mesos_master
  init_opt_boot
  install_opt_mesosdns
  configure_zookeeper
  configure_mesos_master

  install_opt_smack
elif [[ $HOSTNAME == *"slave"* ]]; then
  echo "install for role:slave"
  install_opt_software
  install_opt_mesos_slave
  init_opt_boot
  configure_mesos_slave
  
  install_opt_smack
else
  echo "please use a hostname like: mesos-master-1 or mesos-slave-1"
fi