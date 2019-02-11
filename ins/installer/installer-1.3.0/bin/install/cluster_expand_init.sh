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

NEW_HOST_ONE=$(echo "$EXPAND_HOSTS_LIST" |awk '{print $1}')
#scp $NEW_HOST_ONE:/etc/profile.d/1appenv.sh /etc/profile.d/1appenv.sh
#sed -i -e "s|export LOCAL_IP=.*|export LOCAL_IP=$LOCAL_IP|" /etc/profile.d/1appenv.sh
#sed -i -e "s|export LOCAL_HOST=.*|export LOCAL_HOST=$LOCAL_HOST|" /etc/profile.d/1appenv.sh

for OLD_HOST in $OLD_HOSTS_LIST ; do
    # 解决脚本升级后,新增变量同步
   ssh $OLD_HOST "scp $NEW_HOST_ONE:/etc/profile.d/1appenv.sh /etc/profile.d/1appenv.sh && sed -i -e \"s|export LOCAL_IP=.*|export LOCAL_IP=\$LOCAL_IP|\"  -e \"s|export LOCAL_HOST=.*|export LOCAL_HOST=\$LOCAL_HOST|\"  /etc/profile.d/1appenv.sh  "
   # 机器有变更，重置 firewalld
   ssh $OLD_HOST $APP_BASE/install/host_firewalld.sh
done

for NEW_HOST in $EXPAND_HOSTS_LIST ; do
    scp /etc/profile.d/zoo* $NEW_HOST:/etc/profile.d/
done
$APP_BASE/install/cluster_init.sh  "$EXPAND_HOSTS_LIST"
 
exit 0
