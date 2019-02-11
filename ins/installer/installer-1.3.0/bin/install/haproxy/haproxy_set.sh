#! /bin/bash

if [ $# -lt 1 ] ; then 
  echo "usetag:haproxy_reset.sh true isonlyConfig"
  exit 1
fi
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

isOnlyConfig=$2

$BIN/haproxy_config.sh 1 1 > /etc/haproxy/haproxy.cfg 
if [ -f "/etc/haproxy/user_define.cfg" ] ; then
    cat /etc/haproxy/user_define.cfg | sed -e "s|LOCAL_IP|$LOCAL_IP|" -e "s|HA_VIP|$NEBULA_VIP|" >> /etc/haproxy/haproxy.cfg 
fi
# for appName in ${ALL_APP//,/ } ; do
#     appHosts=`env|grep ${appName}_hosts|awk -F= '{print $2}'`
#     appHome=`echo "$appName" |awk -F_ '{printf("%s_HOME",toupper($1))}' `
#     echo "${appName}_hosts=$appHosts"
#     for APPHOST in $appHosts ; do
#         appHaConfSh=`ssh $APPHOST ls \$$appHome/sbin/haproxy_config.sh 2>/dev/null `
#         if [ "$appHaConfSh" != "" ] ; then
#             break
#         fi
#     done
#     if [ "$appHaConfSh" = "" ] ; then
#         continue
#     fi
#     echo "" >>  /etc/haproxy/haproxy.cfg 
#     echo "########$appName" >>  /etc/haproxy/haproxy.cfg 
#     ssh $APPHOST $appHaConfSh >>  /etc/haproxy/haproxy.cfg 
# done

if [ "$isOnlyConfig" != "true" ] ; then
systemctl restart haproxy
fi
exit $?
