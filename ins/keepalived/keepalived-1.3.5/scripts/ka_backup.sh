#!/bin/bash

. /etc/bashrc
echo "
` date \"+%Y-%m-%d %H:%M:%S\" `
`hostname` is change to backup "  >>"$LOGS_BASE/keepalived/keepalived_notify.log"
if [ "$INSTALL_LVS" = "true" ] ; then

echo "$APP_BASE/install/lvs_realserver.sh start">>"$LOGS_BASE/keepalived/keepalived_notify.log"
$APP_BASE/install/lvs_realserver.sh start

fi

proDomain=$(echo "$PRODUCT_DOMAIN" | awk -F. '{print $1}') 
rootDomain=${PRODUCT_DOMAIN/$proDomain./}
allHostIP="$dns_ips"
# $APP_BASE/install/dns_ka.sh "slave" \"$rootDomain\"  \"$allHostIP\" 
