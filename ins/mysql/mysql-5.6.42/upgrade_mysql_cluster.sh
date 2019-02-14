#!/bin/bash
 
export _LOCALIP=$1
export _LOCALHOSTNAME=$2
export _APP_VERSION=$3
export _FROM_VERSION=$4
 
if [ $# -lt 4 ] ; then 
  echo "usetag: localip localhostname appver _FROM_VERSION"
  exit 1
fi
. ${APP_BASE}/install/funs.sh 

bin=`dirname "${BASH_SOURCE-$0}"`
cd "$bin"
bin=`cd "$bin">/dev/null; pwd`
export APP_HOME="$bin"

export appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
export APPNAME=`toupper "${appName}" `

echo ""> $APP_HOME/conf/.upservers
for HOST in `cat $APP_HOME/conf/servers`; do
        echo "$HOST" >> $APP_HOME/conf/.upservers
        _LOCALIP=`ping -c 1 $HOST |grep "$HOST" |grep "bytes from" |sed -e 's/.*bytes from//' -e 's/:.*//' -e 's/.*(//' -e 's/).*//'`
        _LOCALHOSTNAME="$HOST"
        echo "  upgrade ${appName} on  $HOST ,use shell: $APP_HOME/upgrade_${appName}.sh $_LOCALIP  $_LOCALHOSTNAME $_APP_VERSION $_FROM_VERSION "
        ssh $HOST $APP_HOME/upgrade_${appName}.sh $_LOCALIP  $_LOCALHOSTNAME $_APP_VERSION $_FROM_VERSION
        if [ "$?" != "0" ] ; then
           echo "host $HOST ${appName} upgrad from $_FROM_VERSION to $_APP_VERSION failed"
           exit 1
        fi
done

