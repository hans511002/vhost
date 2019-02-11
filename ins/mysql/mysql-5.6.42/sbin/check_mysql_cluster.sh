#!/bin/bash
#
#
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

APP_HOME="`dirname $bin`"
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
MYCLI_NAME="mysql"

FIRST_HOSTNAME=$1
echo FIRST_HOSTNAME=$FIRST_HOSTNAME
IN_INIT=$2

myhostlist=`cat $APP_HOME/conf/servers`
_IPARR=(${myhostlist//","/ }) 

cnt=${#_IPARR[@]}

_TRYS=0	

if [ "$FIRST_HOSTNAME" = "" ] ; then 
    _LOCAL_DOCKER_CNTER=`docker ps | grep ${appName}-$HOSTNAME | awk '{print $NF}'`
    if [ "$_LOCAL_DOCKER_CNTER" = "" ] ; then
        _LOCAL_DOCKER_CNTER="${appName}-$HOSTNAME"
        docker start $_LOCAL_DOCKER_CNTER
        if [ $? -ne 0 ] ; then 
          echo "start docker containers $_LOCAL_DOCKER_CNTER failed"
          exit 1
        fi
        echo "START_TIME=`date "+%s"`"> $LOGS_BASE/${appName}/check_tmp.log
    fi
else
    FIRST_HOSTNAME=`echo ${FIRST_HOSTNAME//,/ } | awk '{print $1}'`
    _LOCAL_DOCKER_CNTER="${appName}-$FIRST_HOSTNAME"
fi
echo container=${_LOCAL_DOCKER_CNTER}
_RET=0
while [[ "$_RET" != "$cnt" ]]; do
	((_TRYS++))
    if [ "$FIRST_HOSTNAME" = "" ] ; then 
    	_RET=`docker exec $_LOCAL_DOCKER_CNTER $MYCLI_NAME  -e "show status like 'wsrep%size'" 2>&1 |grep wsrep_cluster_size |awk '{print $2}'`
    else
        _RET=`ssh ${FIRST_HOSTNAME} docker ps | grep ${appName}-${FIRST_HOSTNAME} | awk '{print $NF}' `
        if [ "$_RET" = "" ] ; then
            _RET="${appName}-${FIRST_HOSTNAME}"
           ssh ${FIRST_HOSTNAME} $APP_HOME/sbin/start_${appName}.sh  
        fi
        _RET=`ssh ${FIRST_HOSTNAME} "docker exec ${appName}-${FIRST_HOSTNAME} $MYCLI_NAME -e \"show status like 'wsrep_cluster_size'\"  "|grep wsrep_cluster_size`
        _RET=`echo $_RET |awk '{print \$2}'|tr -d '\r' `
    fi
    
	echo "wsrep_cluster_size = $_RET"

	if [[ "$_RET" = "$cnt" ]]; then
		echo "${appName} Cluster Started!"
		exit 0
	fi
    for host in $myhostlist ; do
        _RET=`ssh ${host} docker ps | grep ${appName}-${host} | awk '{print $NF}' `
        if [ "$_RET" = "" ] ; then
            sleep 5
            ssh ${host} $APP_HOME/sbin/start_${appName}.sh  
        fi
    done

	echo "wait 5s for Checking ${appName} Cluster...again.in check_${appName}_cluster.sh"
	sleep 5
	#if [ "$IN_INIT" = "true" ] ; then
    #    if [[ $_TRYS -eq 20 ]]; then
    #		echo "restart other host"
    #		for host in $myhostlist ; do
    #            if [ "$FIRST_HOSTNAME" = "$host" ] ; then
    #		        echo "restart other $host"
    #                ssh ${host}  docker restart ${appName}-${host}
    #            fi
    #        done
    #	fi
    #fi
	if [[ $_TRYS -gt 60 ]]; then
		echo "${appName} Cluster Start wait 300s!"
		break
	fi
done

if [[ "$_RET" = "$cnt" ]]; then
	echo "${appName} Cluster Started!"
	exit 0
else
	echo "${appName} Cluster Start failed, Cluster will be stopped."
fi

exit 1

