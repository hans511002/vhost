#!/bin/bash
. /etc/bashrc

if [ $# -lt 2 ] ; then 
  echo "usetag:host_expand.sh OLD_HOSTS_LIST EXPAND_HOSTS_LIST"
  exit 1
fi

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

OLD_HOSTS_LIST=$1
OLD_HOSTS_LIST="${OLD_HOSTS_LIST//,/ }"

EXPAND_HOSTS_LIST=$2
EXPAND_HOSTS_LIST="${EXPAND_HOSTS_LIST//,/ }"


if [ -f "/etc/sobey/hive/cluster.cfg" ] ; then
  echo "# all app hosts ">/etc/profile.d/app_hosts.sh
  allApps=${ALL_APP//,/ }
	for appName in $allApps ; do
	   hosts=`cat /etc/sobey/hive/cluster.cfg|grep "app.$appName.install.hosts=" |awk -F= '{print $2}'` 
	   if [ "$hosts" != "" ] ; then
	  		echo "export ${appName}_hosts=\"$hosts\" ">>/etc/profile.d/app_hosts.sh
		 else
	   	  hosts=`cat /etc/sobey/hive/cluster.cfg|grep "cluster.$appName.install.hosts=" |awk -F= '{print $2}'`
	   	  if [ "$hosts" != "" ] ; then
  				echo "export ${appName}_hosts=\"$hosts\"">>/etc/profile.d/app_hosts.sh
	   	  fi 
	  fi
	done
	cp.sh scp $HOSTNAME:/etc/profile.d/app_hosts.sh /etc/profile.d/
fi

cmd.sh  $BIN/vip_config.sh


for HOST in $OLD_HOSTS_LIST ; do
	echo "$HOST is old   "
    
done


for HOST in $EXPAND_HOSTS_LIST ; do
	echo "$HOST is new   "
  ssh $HOST rm -rf $LOGS_BASE/docker/docker_containers
  ssh $HOST /bin/start_hive_autostart.sh

done


exit 0
