#!/bin/bash 
#desc:installer auto build
. /etc/bashrc

if [ $# -lt 4 ] ; then 
  echo "usetag: localip localhostname appver fromVer "
  exit 1
fi

APP_HOME=`dirname "${BASH_SOURCE-$0}"`
APP_HOME=`cd "$APP_HOME">/dev/null; pwd`
cd $APP_HOME
export _LOCALIP=$1
export _LOCALHOSTNAME=$2
export _VERSION=$3
export _FROM_VERSION=${4}
echo "_VERSION=$_VERSION"

export appName=${APP_NAME}

if [ -f $APP_HOME/mysql/rollbackMysql.sh ] ; then
    echo "first roll database "
    $APP_HOME/mysql/rollbackMysql.sh $_LOCALIP $_LOCALHOSTNAME $_VERSION $_FROM_VERSION
    if [ "$?" != "0" ] ; then
       echo "rollback mysql database failed,Please manually check the database is correct "
    fi
fi
if [ -f $APP_HOME/mongo/rollbackMongo.sh ] ; then
    echo "first roll database "
    $APP_HOME/mongo/rollbackMongo.sh $_LOCALIP $_LOCALHOSTNAME $_VERSION $_FROM_VERSION
    if [ "$?" != "0" ] ; then
       echo "rollback mongo database failed,Please manually check the database is correct "
    fi
fi

for HOST in `cat $APP_HOME/conf/.upservers`; do
	_LOCALIP=`ping -c 1 $HOST |grep "$HOST" |grep "bytes from" |sed -e 's/.*bytes from//' -e 's/:.*//'  -e 's/.*(//' -e 's/).*//' `
	_LOCALHOSTNAME="$HOST"
	ssh $HOST $APP_HOME/rollback_${APP_NAME}.sh $_LOCALIP  $_LOCALHOSTNAME $_VERSION $_FROM_VERSION
	if [ "$?" != "0" ] ; then
			echo "host $HOST ${APP_NAME} rollback to $_FROM_VERSION  failed"
 	fi
done
rm -rf $APP_HOME/conf/.upservers
exit 0


