#!/bin/bash

set -e
set -u

HADOOP_VERSION="3.4.0"
HADOOP_USER="hadoop"
JAVA_PACKAGE="openjdk-8-jdk"
HADOOP_URL="https://downloads.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_FILE="hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_DIR="hadoop-$HADOOP_VERSION"
DATA_NODE_IP=$(hostname -I | awk '{print $1}')

install_package() {
  if ! dpkg -l | grep -qw $1; then
    sudo apt-get install $1 -y
  fi
}

create_user() {
  if ! id -u $1 > /dev/null 2>&1; then
    sudo adduser $1
    sudo usermod -aG sudo $1
  fi
}

sudo apt-get update
sudo apt-get upgrade -y

install_package $JAVA_PACKAGE
create_user $HADOOP_USER

sudo su - $HADOOP_USER <<EOF

HADOOP_VERSION="3.4.0"
HADOOP_USER="hadoop"
JAVA_PACKAGE="openjdk-8-jdk"
HADOOP_URL="https://downloads.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_FILE="hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_DIR="hadoop-$HADOOP_VERSION"
DATA_NODE_IP=$(hostname -I | awk '{print $1}')

download_file() {
  if [[ ! -f \$1 ]]; then
    curl -O -L --retry 5 \$2
  fi
}

extract_file() {
  if [[ ! -d \$1 ]]; then
    tar -xzvf \$2
  fi
}

download_file $HADOOP_FILE $HADOOP_URL
extract_file $HADOOP_DIR $HADOOP_FILE

mv $HADOOP_DIR hadoop

HADOOP_HOME="/home/hadoop/hadoop"

if ! grep -q "HADOOP_HOME" ~/.bashrc; then
  echo "export HADOOP_HOME=/home/hadoop/hadoop" >> ~/.bashrc
  echo "export HADOOP_INSTALL=\$HADOOP_HOME" >> ~/.bashrc
  echo "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" >> ~/.bashrc
  echo "export HADOOP_COMMON_HOME=\$HADOOP_HOME" >> ~/.bashrc
  echo "export HADOOP_HDFS_HOME=\$HADOOP_HOME" >> ~/.bashrc
  echo "export YARN_HOME=\$HADOOP_HOME" >> ~/.bashrc
  echo "export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native" >> ~/.bashrc
  echo "export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin" >> ~/.bashrc
  echo "export HADOOP_OPTS=\"-Djava.library.path=\$HADOOP_HOME/lib/native\"" >> ~/.bashrc
fi

source ~/.bashrc

cd ./hadoop/etc/hadoop

echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> hadoop-env.sh

cat <<EOF1 > core-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
   <property>
        <name>hadoop.tmp.dir</name>
        <value>/home/hadoop/tmpdata</value>
        <description>A base for other temporary directories.</description>
    </property>
    <property>
        <name>fs.default.name</name>
        <value>hdfs://localhost:9000</value>
        <description>The name of the default file system></description>
    </property>
</configuration>
EOF1

cat <<EOF2 > hdfs-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
        <property>
                <name>dfs.data.dir</name>
                <value>/home/hadoop/dfsdata/namenode</value>
        </property>
        <property>
                <name>dfs.data.dir</name>
                <value>/home/hadoop/dfsdata/datanode</value>
        </property>
        <property>
                <name>dfs.replication</name>
                <value>1</value>
        </property>
        <property>
                <name>dfs.permissions</name>
                <value>false</value>
        </property>
        <property>
                <name>dfs.webhdfs.enabled</name>
                <value>true</value>
        </property>
        <property>
                <name>dfs.client.use.datanode.hostname</name>
                <value>true</value>
        </property>
        <property>
                <name>dfs.datanode.use.datanode.hostname</name>
                <value>true</value>
        </property>
        <property>
                <name>dfs.datanode.hostname</name>
                <value>$DATA_NODE_IP</value>
        </property>
</configuration>
EOF2

cat <<EOF3 > mapred-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>


<configuration>
        <property>
                <name>mapreduce.framework.name</name>
                <value>yarn</value>
        </property>
</configuration>
EOF3

cat <<EOF4 > yarn-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>


<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>localhost</value>
  </property>
  <property>
    <name>yarn.acl.enable</name>
    <value>0</value>
  </property>
  <property>
    <name>yarn.nodemanager.env-whitelist</name>
    <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PERPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
  </property>
</configuration>
EOF4

cd

mkdir -p tmpdata
mkdir -p dfsdata/namenode
mkdir -p dfsdata/datanode

chmod -R 755 tmpdata
chmod -R 755 dfsdata

EOF