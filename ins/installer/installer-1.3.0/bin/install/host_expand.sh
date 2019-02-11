#! /bin/bash

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

for HOST in $OLD_HOSTS_LIST ; do
	echo "$HOST is old   "
    
done
for HOST in $EXPAND_HOSTS_LIST ; do
	echo "$HOST is new   "
    
done
exit 0
