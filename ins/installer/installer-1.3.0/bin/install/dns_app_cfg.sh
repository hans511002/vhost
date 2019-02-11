#!/bin/bash

. /etc/bashrc
. $APP_BASE/install/funs.sh
bin=$(cd $(dirname $0); pwd)

# 1.0 不安装DNS
if [ "$INSTALL_DNS" != "true" ] ; then
    exit 0
fi

if [ "$#" != "3" ] ; then
    echo "Usage:add/del appname hostip
    ex: dns_app_cfg.sh add appname 172.16.131.135"
    exit 1
fi
optType=$1
appName=$2
appHostIp=$3

if [ "$optType" != "add" -a  "$optType" != "del"  ] ; then
    echo "usetag:add/del appname host hostip
    ex: dns_app_cfg.sh add  appname node04 172.16.131.135"
    exit 1
fi

#funs
dnsHosts=`getDnsHostList`
dnsIPs=`getDnsIpList`

dnsHosts=${dnsHosts//,/ }
dnsIPs=${dnsIPs//,/ }
proDomain=$(echo "$PRODUCT_DOMAIN" | awk -F. '{print $1}')
rootDomain=${PRODUCT_DOMAIN/$proDomain./}
echo "rootDomain=$rootDomain"

priKey="vQ9U23WtJg2C9RaEItv42AaI/aECSiKW7oszg6IWQFoyQ49Rex/KRl3PWaBdLyty/ofaYhy/DxvjnP2T7HEFcw=="

if [ "$optType" = "add" ] ; then
    echo "add $appName dns to host ${appHostIp}"
    for host in $dnsHosts; do
    echo "config on $host:"
    ssh $host "nsupdate -y ${rootDomain//./}:$priKey" <<EOF
server 127.0.0.1
zone $rootDomain
update add $appName.$rootDomain. 5 IN A ${appHostIp}
send
quit
EOF
    echo "host $appName.$rootDomain:"
    host $appName.$rootDomain
    sleep 0.5
    done
elif [ "$optType" = "del" ] ; then
    echo "del host ${appHostIp} from dns"
    for host in $dnsHosts; do
    echo "config on $host:"
    ssh $host "nsupdate -y ${rootDomain//./}:$priKey" <<EOF
server 127.0.0.1
zone $rootDomain
update delete $appName.$rootDomain. IN A ${appHostIp}
send
quit
EOF
    echo "host $appName.$rootDomain:"
    host $appName.$rootDomain
    sleep 0.5
    done
fi

