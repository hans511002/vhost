#!/bin/bash

. /etc/bashrc
echo "
` date \"+%Y-%m-%d %H:%M:%S\" `
`hostname` is change to master "  >>"$LOGS_BASE/keepalived/keepalived_notify.log"
. $APP_BASE/install/funs.sh
if [ "$INSTALL_LVS" = "true" ] ; then

    ipvsadm --set 30 5 50
    $APP_BASE/install/iptable_trans.sh start
    
    echo "$APP_BASE/install/lvs_realserver.sh stop">>"$LOGS_BASE/keepalived/keepalived_notify.log"
    $APP_BASE/install/lvs_realserver.sh stop 2>&1 >>"$LOGS_BASE/keepalived/keepalived_notify.log"
 
    appHosts=`getAppHosts haproxy `
    echo "haproxy_hosts=$appHosts">>"$LOGS_BASE/keepalived/keepalived_notify.log"
    for HOST in $appHosts ; do
        if [ "$HOST" != "$LOCAL_HOST" ] ; then
            ssh $HOST $APP_BASE/install/lvs_realserver.sh start 2>&1 >>"$LOGS_BASE/keepalived/keepalived_notify.log"
        fi
    done
    appHosts=`getAppHosts keepalived `
    echo "keepalived_hosts=$appHosts">>"$LOGS_BASE/keepalived/keepalived_notify.log"
    for HOST in $appHosts ; do
        if [ "$HOST" != "$LOCAL_HOST" ] ; then
            ssh $HOST $APP_BASE/install/iptable_trans.sh stop 2>&1 >>"$LOGS_BASE/keepalived/keepalived_notify.log"
        fi
    done   
fi

if [ "$PRODUCT_DOMAIN" != "" ] ; then
    proDomain=$(echo "$PRODUCT_DOMAIN" | awk -F. '{print $1}') 
    rootDomain=${PRODUCT_DOMAIN/$proDomain./}
    echo "rootDomain=$rootDomain"
    appHosts=`getAppHosts keepalived `
    allHostIP="${dns_ips}"
    # $APP_BASE/install/dns_ka.sh "master" "$rootDomain"   "$allHostIP"
    for HOST in ${allHostIP//,/ } ; do
        if [ "$HOST" != "$LOCAL_IP" ] ; then
            HOSTIP=`getHostIPFromPing $HOST`
            # ssh $HOST $APP_BASE/install/dns_ka.sh "slave" \"$rootDomain\"  \"$allHostIP\"  
        fi
    done
fi

