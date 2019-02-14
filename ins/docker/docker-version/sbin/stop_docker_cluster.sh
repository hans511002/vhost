#!/bin/bash
. /etc/bashrc

bin=$(cd $(dirname $0); pwd)
APP_HOME="`dirname $bin`"
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
order=`echo $0 |sed -e "s|.*/||" -e "s|_.*||"`

for host in `cat $APP_HOME/conf/servers`; do
    echo "$order ${appName} on $host: "
    ssh $host "${APP_HOME}/sbin/${order}_${appName}.sh"
    sleep 0.5
done


