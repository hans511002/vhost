#!/bin/bash 

#首先还是从当前shell目录下读取配置
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

APP_HOME="`dirname $bin`"
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
MYCLI_NAME="mysql"

APP_HOSTS=(`cat $APP_HOME/conf/servers`)
cnt=${#APP_HOSTS[@]}
_FIRST=false

oneHiveHiveDB=false
clusterHostSize=0
for HOST in `cat $APP_HOME/conf/servers` ; do
    hivedbTables=`ssh $HOST ls -l ${DATA_BASE}/${appName}/mysql/ 2>/dev/null |wc -l `
    if [ "$hivedbTables" -gt "10" ] ; then
        oneHiveHiveDB="true"
    fi
    ((clusterHostSize++))
done
echo "Have initialized the hivedb database: $oneHiveHiveDB"
if [ "$oneHiveHiveDB" = "true" -a "$clusterHostSize" -gt "1" ] ; then
    FIRST_HOSTNAME=`$bin/getFirstHost.sh `
    res=$?
    FIRST_HOSTNAME=`echo "$FIRST_HOSTNAME"|grep "FIRST_HOSTNAME="|sed -e "s|FIRST_HOSTNAME=||"`
    if [ "$res" != "0" ] ; then
        clusterIDSize=$res
        echo "clusterIDSize=$clusterIDSize"
        if [ "$clusterHostSize" = "$clusterIDSize" ] ; then
            FIRST_HOSTNAME=""
            echo "Each machine is a grouping cluster"
            exit 1
        else
            exit 1
        fi
    fi
else
    echo "new cluster inited ,not check wsrep position"
fi

echo "Starting ${appName} Cluster...FIRST_HOSTNAME=$FIRST_HOSTNAME"

if [ "$FIRST_HOSTNAME" = ""  ] ; then
    FIRST_HOSTNAME=${APP_HOSTS[0]} 
fi
SSH_CMD="ssh  ${FIRST_HOSTNAME} '${APP_HOME}/sbin/start_${appName}.sh'"
echo SSH_CMD=$SSH_CMD
$SSH_CMD
FIRST_HOSTNAME_STARED=false
while [[ "$_FIRST" = "false" ]]; do
    #_RET=`ssh ${FIRST_HOSTNAME} "docker exec ${appName}-${FIRST_HOSTNAME} ${MYCLI_NAME} -uroot -p'$0BeyHive^2olSix' -e \"show status like 'wsrep_cluster_size'\"  "|grep wsrep_cluster_size`
    # 		echo "wsrep_cluster_size =${_RET}"
    #_RET=`echo $_RET |awk '{print \$2}'|tr -d '\r' `
	#echo "wsrep_cluster_size =${_RET}" 
	host_out=$(ssh $FIRST_HOSTNAME docker exec ${appName}-$FIRST_HOSTNAME ${MYCLI_NAME} -N -e "\"show status  WHERE variable_name LIKE 'wsrep_cluster_size' \"" 2>/dev/null)
    echo "host_out=$host_out"
    OTHER_SIZE=`echo $host_out | grep wsrep_cluster_size |awk '{print $2}'  ` 
	host_out=$(ssh $FIRST_HOSTNAME docker exec ${appName}-$FIRST_HOSTNAME ${MYCLI_NAME} -N -e "\"show status  WHERE variable_name  LIKE 'wsrep_ready'  \"" 2>/dev/null)
    OTHER_STATUS=`echo $host_out | grep wsrep_ready |awk '{print $2}' ` 
	echo "wsrep_cluster_size =${OTHER_SIZE}   wsrep_ready=$OTHER_STATUS" 
    OTHER_SIZE=`echo $OTHER_SIZE  |tr -d '\r' `
	echo "wsrep_cluster_size =${OTHER_SIZE}   wsrep_ready=$OTHER_STATUS" 
	_RET=$OTHER_SIZE

	((_TRYS++))
	if [ "$_RET" = "" ] ; then
	   _RET=0
	fi
	if [ "$_RET" -ge "1" ] ; then
           if [ "$OTHER_STATUS" = "ON" ] ; then
                _FIRST=true
    			echo "${appName} ${FIRST_HOSTNAME} Started."
    			break
    	    else
    	        if [ "$_TRYS" -eq "30" ] ; then
                      ssh ${FIRST_HOSTNAME} "${APP_HOME}/sbin/stop_${appName}.sh"
            	      sleep 2
            	      ssh ${FIRST_HOSTNAME} "${APP_HOME}/sbin/start_${appName}.sh"
                fi
            fi
	fi
	echo "wait 5s for Checking ${appName} Cluster...again.in start_${appName}_cluster.sh"
	sleep 5
	if [[ $_TRYS -gt 50 ]]; then
		echo "${appName} Cluster Start wait 250s!"
		break
	fi
done

if [ "$_FIRST" != "true" ] ; then
  echo "fisrt host[$FIRST_HOSTNAME] start failed "
 exit 1
fi
	sleep 5
for (( n=0;n<cnt;n++)) ;     do	
 	_IP=${APP_HOSTS[$n]}
 	if [ "$FIRST_HOSTNAME" != "$_IP" ] ; then 
	sleep 10
     	echo "${_IP} ${APP_HOME}/sbin/start_${appName}.sh "
     	ssh ${_IP} "${APP_HOME}/sbin/start_${appName}.sh"
 	fi
 done

. $bin/check_${appName}_cluster.sh $FIRST_HOSTNAME true
