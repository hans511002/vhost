#! /bin/bash

if [ $# -lt 1 ] ; then 
  echo "usetag:haproxy_reset.sh true"
  exit 1
fi
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ "$haproxy_hosts" = "" ] ; then
    echo "haproxy not properly installed  "
    exit 1
fi


for HOST in ${haproxy_hosts//,/ } ; do
    ssh $HOST "$BIN/haproxy_set.sh  true"
    if [ "$?" != "0" ] ; then
        echo "ssh $HOST systemctl status haproxy -l "
        exit 1
    fi
done

exit 0
