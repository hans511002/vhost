#!/bin/bash     
BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
 
APP_HOME="$BIN"
APP_HOME=`dirname $APP_HOME`
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`

nohup $BIN/check_start.sh >> ${LOGS_BASE}/$appName/auto_start.log 2>&1 &
