#! /bin/bash

if [ $# -lt 2 ] ; then 
  echo "usetag:zookeeper_config.sh CLUSTER_HOST_LIST EXPAND_HOSTS_LIST"
  exit 1
fi
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

CLUSTER_HOST_LIST=$1
CLUSTER_HOST_LIST="${CLUSTER_HOST_LIST//,/ }"

for HOST in $CLUSTER_HOST_LIST ; do
	echo "$HOST update env ZOOKEEPER_URL=$ZOOKEEPER_URL"
    ssh $HOST "sed -i -e 's/export ZOOKEEPER_URL=.*/export ZOOKEEPER_URL=$ZOOKEEPER_URL/' /etc/profile.d/zookeeper.sh  "
	echo "$HOST exec: ${ZOOKEEPER_HOME}/sbin/stop_zookeeper.sh;${ZOOKEEPER_HOME}/sbin/start_zookeeper.sh"
    ssh $HOST "${ZOOKEEPER_HOME}/sbin/stop_zookeeper.sh"
    ssh $HOST "${ZOOKEEPER_HOME}/sbin/start_zookeeper.sh"
done
