#!/bin/bash

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`
. ${APP_BASE}/install/funs.sh

APP_HOME="`dirname $bin`"
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
MYCLI_NAME="mysql"

port=`cat $APP_HOME/conf/my.cnf|grep port |awk -F= '{print $2}'`
if [ "$port" = "" ] ; then
    port=3306
fi

runningHosts=""
for HOST in `cat $APP_HOME/conf/servers` ; do
    if [ "`testHostPort $HOST 22`" != "open" ] ; then
        echo "$HOST down" >&2
        continue
    fi
    if [ "`testHostPort $HOST $port `" = "open" ] ; then
        if [ "$runningHosts" = "" ] ; then
            runningHosts="$HOST"
        else   
            runningHosts="$runningHosts,$HOST"
        fi
    fi
done
declare -A HOST_CLS_POSTION
echo "runningHosts=${runningHosts//,/ }" 

grepKey="mysqld_safe WSREP: Recovered position"

HOST_CLS_ID=""
brainSplit=false
yyyymmdd=`date +%Y%m%d`
clsBrainSplit=false

if [ "$runningHosts" != "" ] ; then
    runningHosts="$runningHosts,"
    runSize=(${runningHosts//,/ })
    runSize=${#runSize[@]}
    echo "runningHosts=${runningHosts//,/ }" >&2
    declare -A HOST_CLS_SIZE
    declare -A HOST_CLS_STATUS
     
    for HOST in ${runningHosts//,/ } ; do
        host_out=$(ssh $HOST docker exec ${appName}-$HOST ${MYCLI_NAME} -N -e "\"show status  WHERE variable_name LIKE 'wsrep_cluster_size' \"" 2>/dev/null)
        OTHER_SIZE=`echo $host_out | grep wsrep_cluster_size |awk '{print $2}' ` 
        host_out=$(ssh $HOST docker exec ${appName}-$HOST ${MYCLI_NAME} -N -e "\"show status  WHERE variable_name  LIKE 'wsrep_ready'  \"" 2>/dev/null)
        OTHER_STATUS=`echo $host_out | grep wsrep_ready |awk '{print $2}' ` 
        echo "$HOST  wsrep_cluster_size=$OTHER_SIZE wsrep_ready=$OTHER_STATUS" >&2
        
        host_out=$(ssh $HOST docker exec ${appName}-$HOST ${MYCLI_NAME} -N -e "\"show status  WHERE variable_name  LIKE 'wsrep_local_state_uuid'  \"" 2>/dev/null)
        host_out=`echo $host_out | grep wsrep_local_state_uuid |awk '{print $2}' ` 
        if [ "$HOST_CLS_ID" = "" ] ; then
            HOST_CLS_ID="$host_out"
        else   
            if [ "$HOST_CLS_ID" != "$host_out" ] ; then
                echo "HOST=$HOST HOST_CLS_ID=$HOST_CLS_ID host_out=$host_out" >&2
                brainSplit=true
                clsBrainSplit=true
            fi
        fi
        host_out=$(ssh $HOST docker exec ${appName}-$HOST ${MYCLI_NAME} -N -e "\"show status  WHERE variable_name  LIKE 'wsrep_last_committed'  \"" 2>/dev/null)
        echo "wsrep_last_committed=$host_out"
        host_out=`echo $host_out | grep wsrep_last_committed |awk '{print $2}' ` 
        
        if [ "$host_out" = "" ] ; then
            echo "$HOST container error: need recreate " >&2
            continue
        fi
        
        HOST_CLS_POSTION[$HOST]=$host_out
        echo "$HOST  $HOST_CLS_ID:$host_out" >&2

        if [ "$OTHER_SIZE" = "" ] ; then
            HOST_CLS_SIZE[$HOST]=0
        else   
            HOST_CLS_SIZE[$HOST]=$OTHER_SIZE
        fi
        if [ "$OTHER_STATUS" != "ON" ] ; then
            HOST_CLS_STATUS[$HOST]=0
        else   
            HOST_CLS_STATUS[$HOST]=1
        fi
    done
    
    for HOST in  ${!HOST_CLS_SIZE[@]} ;  do
        hostSize=${HOST_CLS_SIZE[$HOST]}
        if [ "$hostSize" = "0" ] ; then
            ssh $HOST docker stop ${appName}-$HOST
            ((runSize--))
            runningHosts=${runningHosts//$HOST,/}
        fi
    done
    brainSplit=false
    runningHosts=""
    for HOST in  ${!HOST_CLS_SIZE[@]} ; do
        hostSize=${HOST_CLS_SIZE[$HOST]}
        hostStatus=${HOST_CLS_STATUS[$HOST]}
        if [ "$hostSize" -lt "$runSize" -o  "$hostStatus" != "1"  ] ; then
            echo "hostSize=$hostSize runSize=$runSize" >&2
            brainSplit=true
            break
        fi
        if [ "$runningHosts" = "" ] ; then
            runningHosts="$HOST"
        else   
            runningHosts="$runningHosts,$HOST"
        fi
    done
    maxPos=0
    allIsNULL=true
    for HOST in  ${!HOST_CLS_POSTION[@]} ; do
        posId=${HOST_CLS_POSTION[$HOST]}
        # echo "posId=$posId"
        if [ "$posId" = "" ] ; then
            continue
        elif [ "$maxPos" = "0" ] ; then
            allIsNULL=false
            maxPos=$posId
            FIRST_HOSTNAME=$HOST
        elif [ "$maxPos" != "$posId" ] ; then
            brainSplit=true
            allIsNULL=false
        fi
        if [ "$clsBrainSplit" = "false" ] ; then
            if [ "$maxPos" -lt "$posId" ] ; then
                maxPos=$posId
                FIRST_HOSTNAME=$HOST
            fi
        fi
    done
    if [ "$allIsNULL" = "true" ] ; then
        echo "all host is failed,stop all "  
        echo "all host is failed,stop all "  >&2
       for HOST in ${runningHosts//,/ } ; do
            ssh $HOST docker stop ${appName}-$HOST  >&2
        done
        runningHosts=""
        brainSplit="false"
    else
        echo "maxPos=$maxPos"
        if [ "$brainSplit" = "true" ] ; then
            if [ "$clsBrainSplit" = "false" ] ; then
                echo "FIRST_HOSTNAME=$FIRST_HOSTNAME" >&2
                echo "FIRST_HOSTNAME=$FIRST_HOSTNAME" 
                exit 0
            fi
            echo "line:136 ${appName} database cluster brain split or data not sync , Please solve this problem manually  " >&2
            exit 1
        fi
        FIRST_HOSTNAME=`echo "${runningHosts//,/ }"|awk '{print $1}'`
        echo "FIRST_HOSTNAME=$FIRST_HOSTNAME" >&2
        echo "FIRST_HOSTNAME=$FIRST_HOSTNAME" 
        exit 0
    fi
fi

#exit 1
declare -A HOST_CLS_IDS

for HOST in `cat $APP_HOME/conf/servers` ; do
    if [ "`testHostPort $HOST 22`" != "open" ] ; then
        echo "hsot down:$HOST " >&2
        continue
    fi
    logCount=`ssh $HOST docker logs -t  --since $yyyymmdd ${appName}-$HOST  2>&1  |wc -l`
    echo "$HOST logStartCount=$logCount" >&2
    echo "ssh $HOST docker start  ${appName}-$HOST " >&2
    ssh $HOST docker start  ${appName}-$HOST >&2
    logEnd=`expr $logCount + 200`
    recoveredPostion=""
    trytime=0
    while [ "$recoveredPostion" = "" ] ;  do 
        ((trytime++))
        if [ "$trytime" -gt "60" ] ; then
            break
        fi
        recoveredPostion=` ssh $HOST docker logs  -t  --since $yyyymmdd ${appName}-$HOST 2>&1  |sed -n "$logCount,${logEnd}p" |grep "$grepKey"|tail -n 1 `
        if [ "$recoveredPostion" = "" ] ; then
            sleep 1
            continue
        else
            echo "ssh $HOST docker stop  ${appName}-$HOST " >&2
            ssh $HOST docker stop  ${appName}-$HOST
            recoveredPostion=`echo "$recoveredPostion" | sed -e s"|.*Recovered position||"`
            echo "$HOST WSREP Recovered position: $recoveredPostion" >&2
            clsId=`echo $recoveredPostion | awk -F: '{print $1}'`
            posId=`echo $recoveredPostion | awk -F: '{print $2}'`
            HOST_CLS_POSTION[$HOST]=$posId
            if [ "$HOST_CLS_ID" = "" ] ; then
                HOST_CLS_ID="$clsId"
            else
                if [ "$HOST_CLS_ID" != "$clsId" ] ; then
                    brainSplit=true
                fi
            fi
            if [ -z "${HOST_CLS_IDS[$clsId]}" ]; then
                HOST_CLS_IDS[$clsId]=1
            else
                let HOST_CLS_IDS[$clsId]++
            fi
        fi
    done
done
if [ "$brainSplit" = "true" ] ; then
    clusterHostSize=0
    clusterIDSize=0
    for clsId in ${!HOST_CLS_IDS[@]}; do
        echo "clsId=$HOST_CLS_ID hostSize=${HOST_CLS_IDS[$clsId]}"
        ((clusterHostSize+=${HOST_CLS_IDS[$clsId]}))
        ((clusterIDSize++))
    done
    if [ "$clusterIDSize" -ne "$clusterHostSize" ] ; then
        echo "${appName} database cluster brain split, Please solve this problem manually"  >&2
        echo "${appName} database cluster brain split, Please solve this problem manually" 
        echo "There are multiple cluster groupings"  >&2
        echo "There are multiple cluster groupings"  
        echo "cluster host size $clusterHostSize  cluster id size:$clusterIDSize"   >&2
        echo "cluster host size $clusterHostSize  cluster id size:$clusterIDSize"  
        exit $clusterIDSize
    else
        echo "FIRST_HOSTNAME=$HOST" >&2
        echo "FIRST_HOSTNAME=$HOST" 
        exit 0
    fi
fi
maxPos=0
maxHostName=""
for HOST in  ${!HOST_CLS_POSTION[@]} ; do
    posId=${HOST_CLS_POSTION[$HOST]}
    if [ "$maxHostName" = "" ] ; then
        maxPos=$posId
        maxHostName=$HOST
    elif [ "$posId" -gt "$maxPos" ] ; then
        maxPos=$posId
        maxHostName=$HOST    
    fi
done
echo "FIRST_HOSTNAME=$maxHostName" >&2
echo "FIRST_HOSTNAME=$maxHostName"

exit 0
