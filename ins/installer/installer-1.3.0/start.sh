#!/usr/bin/env bash
# Modelled after $INSTALLER_HOME/sbin/start-installer.sh.
# Start hadoop hbase daemons.
# Run this on master node.

#rm -rf $bin/conf/cluster.cfg $bin/bin/install/docker_containers
#find $bin -name "*.sh"|xargs chmod +x 
#chmod +x  $bin/sbin/installer

bin=$(cd $(dirname $0); pwd)
systemctl stop firewalld
service firewalld stop
chmod +x -R $bin 

$bin/sbin/installer master start $@
