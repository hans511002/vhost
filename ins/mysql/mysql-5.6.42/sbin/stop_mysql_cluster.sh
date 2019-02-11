#!/bin/bash

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
cd "$BIN"
APP_HOME="$BIN"
APP_HOME=`dirname $APP_HOME`
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`

# appHome=`env | grep "$(echo $appName | awk '{print toupper($0)}')_HOME" | awk -F '=' '{print $NF}'`

for host in `cat ${APP_HOME}/conf/servers`; do
    echo "Stop ${APP_HOME} on $host: "
    ssh $host "${APP_HOME}/sbin/stop_${appName}.sh"
    sleep 0.5
done
