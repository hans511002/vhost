#!/bin/bash     

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

RUNED=`ps -ef|grep "$BIN/check_start.sh"|grep -v grep|grep "/bin/bash" |wc -l `
if [ "$RUNED" != "" ]; then
    if [ "$RUNED" -gt 2  ]; then
        # echo "check_start.sh is running"
        exit 0
    fi
fi
. ${APP_BASE}/install/funs.sh

APP_HOME="`dirname $BIN`"
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
MYCLI_NAME="mysql"

port=`cat $APP_HOME/conf/my.cnf|grep port |awk -F= '{print $2}'`
if [ "$port" = "" ] ; then
    port=3306
fi

HOSTNAME=`hostname`
PING=false
INHOST=false
PINGHOSTNAME=
HOST_SIZE=0
for host in `cat $APP_HOME/conf/servers ` ; do 
    ((HOST_SIZE++))
    if [ "$HOSTNAME" != "$host" ] ; then
        sshStatus=`testHostPort $host  22 `
        if [ "$sshStatus" = "open" ] ; then
            PING=true
        fi
        sshStatus=`testHostPort $host $port `
        if [ "$sshStatus" = "open" ] ; then
            PINGHOSTNAME="$PINGHOSTNAME $host"
        fi
    else
        INHOST="true"
    fi
done

if [ "$INHOST" != "true" ] ; then
   exit 1
fi
if [ "$HOST_SIZE" = "1" ] ; then
    PING="true"
fi
if [ "$PING" = "false" ] ; then
    exit 1
fi


APPPARDIR=`dirname $APP_HOME`
#判断容器是否存在
container=`docker ps -a |grep "${appName}-"|awk '{print $NF}'`
if [ "$container" = "" ] ; then
    $APP_BASE/install/${appName}/${appName}-$_APP_VERSION-run.sh 
    exit 0
fi

#判断是否能连 
HOST_LIST=`cat $APP_HOME/conf/servers`
HOST_SIZE=0
for host in $HOST_LIST ; do 
    ((HOST_SIZE++))
done


MSYQL_STAUS_FILE="$LOGS_BASE/${appName}/check_tmp.log"

restartApp(){
if [ "$HOST_SIZE" = "1" -o "$PINGHOSTNAME" != "" ] ; then
container=`docker ps  -a  |grep "${appName}-"|awk '{print $NF}'`
_container=`docker ps |grep "$container"|awk '{print $NF}'`
if [ "$_container" = "" ] ; then
    echo "`date` docker start $container"
    docker restart $container
    echo "START_TIME=`date "+%s"`"> $MSYQL_STAUS_FILE
else
    START_TIME=0
    nowTime=`date "+%s"`
    if [ -f "$MSYQL_STAUS_FILE" ] ; then
        START_TIME=`cat $MSYQL_STAUS_FILE|grep "START_TIME="|sed -s "s|START_TIME=||"`
    fi
    if [ "`expr $START_TIME  + 60`" -gt "$nowTime" ] ; then
        exit 0
    fi
    syncNum=$(docker exec ${_container} ps -ef | grep sync |wc -l)
	if [ "$syncNum" -gt "0" ] ; then
	    echo "data sync"
	    exit 0
	fi
	docker restart $container
    echo "START_TIME=`date "+%s"`"> $MSYQL_STAUS_FILE
fi
fi
}

if [[ `netstat -ntl | grep LISTEN | awk '/:4567/{print $4}' | grep '4567$' | wc -l` == "0" ]]; then
    restartApp
    sleep 2
else
    _LOCAL_APP_CONTAINER=$container
    #rm -f $_TMP_FILE
    ALL_OUT=$(docker exec ${_LOCAL_APP_CONTAINER} $MYCLI_NAME  -N -e "show status  WHERE variable_name  LIKE 'wsrep_ready' ")
    wsrep_ready=`echo $ALL_OUT | grep wsrep_ready |awk '{print $2}'  ` 
    if [ "$wsrep_ready" = "OFF" ] ; then
        OTHER_OFF_HOSTS=""
        OTHER_ON_HOSTS=""
        for host in $HOST_LIST ; do 
            if [ "$host" = "$HOSTNAME" ] ; then
                continue
            fi
            sshStatus=`testHostPort $host  4567 `
            if [ "$sshStatus" != "open" ] ; then
                 continue
            fi
            host_out=$(ssh $host docker exec ${appName}-$host $MYCLI_NAME -N -e "\"show status  WHERE variable_name  LIKE 'wsrep_ready' \"")
            OTHER_STATUS=`echo $host_out | grep wsrep_ready |awk '{print $2}'  ` 
            if [ "$OTHER_STATUS" = "OFF" ] ; then
                OTHER_OFF_HOSTS="$OTHER_OFF_HOSTS $host"
            fi
            if [ "$OTHER_STATUS" = "ON" ] ; then
                OTHER_ON_HOSTS="$OTHER_ON_HOSTS $host"
            fi
        done
        
        if [ "$OTHER_ON_HOSTS" = "" ] ; then
            echo "`date` all host dead"
            $APP_HOME/sbin/stop_${appName}_cluster.sh
            $APP_HOME/sbin/start_${appName}_cluster.sh
        else
            if [ "$OTHER_OFF_HOSTS" = "" ] ; then
                restartApp
                sleep 2
            else
                OTHER_OFF_HOSTS="$OTHER_OFF_HOSTS $HOSTNAME"
                for host in $OTHER_OFF_HOSTS ; do
                    echo "`date` ssh $host $APP_HOME/sbin/stop_${appName}.sh"
                    ssh $host $APP_HOME/sbin/stop_${appName}.sh
                done
                sleep 1
                for host in $OTHER_OFF_HOSTS ; do
                    echo "`date` ssh $host $APP_HOME/sbin/start_${appName}.sh"
                    ssh $host $APP_HOME/sbin/start_${appName}.sh
                done                 
            fi
        fi     
    fi 
fi                


