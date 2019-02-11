#!/bin/bash

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

ppidcmdline=`cat /proc/$PPID/cmdline `

APP_HOME="`dirname $bin`"
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
MYCLI_NAME="mysql"

if [ "${ppidcmdline}" != "${ppidcmdline//${appName}_status/}" ] ; then
    psefIds=`ps -ef| grep $bin/check_${appName}.sh |grep -v $$ | grep -v grep | awk '{printf("%s,%s ", $2,$3);}' `
    if [ "$psefIds" != "" ] ; then
        for pid in $psefIds ; do
            ppid=${pid//*,/}
            pid=${pid//,*/}
            if [ "$pid" != "$$" ] ; then
                ppidcmdline=`cat /proc/$ppid/cmdline `
                if [ "${ppidcmdline}" != "${ppidcmdline//${appName}_status/}" ] ; then
                    kill -9 $pid 2>/dev/null
                fi
            fi
        done
        #pis=($psefIds)
        #if [ ${#pis[@]} -gt 10 ] ; then
        #    kill -9 $psefIds
        #fi
    fi
fi

. /etc/bashrc
LOGS_HOME=`dirname $APP_HOME`
LOGS_HOME=`dirname $LOGS_HOME`
LOGS_BASE=${LOGS_BASE:=$LOGS_HOME/logs}

port=`cat $APP_HOME/conf/my.cnf|grep port |awk -F= '{print $2}'`
if [ "$port" = "" ] ; then
    port=3306
fi

MYCLI_CLIENT=`which $MYCLI_NAME 2>/dev/null`
APP_LOG_DIR="${LOGS_BASE}/${appName}"
mycliExecStatus(){
HOST=$1
if [ "$MYCLI_CLIENT" = "" ] ; then
    if [ "$HOST" = "" ] ; then
        appContainerName=`docker ps -a | grep ${appName}-$HOSTNAME | awk '{print $NF}'`
        if [ "$appContainerName" != "" ] ; then
            docker exec $appContainerName $MYCLI_NAME  -N -e "show status  WHERE variable_name  LIKE 'wsrep_ready' OR variable_name LIKE 'wsrep_cluster_size' " 2>/dev/null
        fi
    else
        appContainerName=`ssh $HOST docker ps -a | grep ${appName}-$HOST | awk '{print $NF}'`
        if [ "$appContainerName" != "" ] ; then
            ssh $host docker exec $appContainerName $MYCLI_NAME -N -e "\"show status  WHERE variable_name  LIKE 'wsrep_ready' OR variable_name LIKE 'wsrep_cluster_size' \""  2>/dev/null
        fi
    fi
else
    if [ -d "/etc/mysql/conf.d" ] ; then
        mkdir /etc/mysql/conf.d -p
    fi
    if [ "$HOST" = "" ] ; then
        $MYCLI_CLIENT -h $HOSTNAME -P $port -u root -p'$0BeyHive^2olSix'  -N -e "show status  WHERE variable_name  LIKE 'wsrep_ready' OR variable_name LIKE 'wsrep_cluster_size' "  2>/dev/null
    else
        $MYCLI_CLIENT -h $HOST -P $port -u root -p'$0BeyHive^2olSix'  -N -e "show status  WHERE variable_name  LIKE 'wsrep_ready' OR variable_name LIKE 'wsrep_cluster_size' "  2>/dev/null
    fi
fi
}

HOST_LIST=`cat $APP_HOME/conf/servers`
HOST_SIZE=0
for host in $HOST_LIST ; do 
((HOST_SIZE++))
done
_TMP_FILE="/tmp/${appName}_status"

if [[ `ss -ntl | grep LISTEN | awk '/:'${port}'/{print $4}' | grep "${port}$" | wc -l` == "1" ]];
then
	_LOCAL_APP_CONTAINER=`docker ps | grep ${appName}| awk '{print $NF}'`
   if [ "$_LOCAL_APP_CONTAINER" = "" ] ; then
        echo -e "HTTP/1.1 503 Service Unavailable\r\n"
  		exit 1
   fi

    #rm -f $_TMP_FILE
    ALL_OUT=$(mycliExecStatus)
    _WSREP_STATUS=`echo "$ALL_OUT" | grep wsrep_ready |awk '{print $2}'  ` 
    _CLUSTER_SIZE=`echo "$ALL_OUT" | grep wsrep_cluster_size |awk '{print $2}'  ` 
    #echo "_CLUSTER_SIZE=$_CLUSTER_SIZE _WSREP_STATUS=$_WSREP_STATUS"
    if [ "$_WSREP_STATUS" = "OFF" ] ; then
        syncNum=$(docker exec ${_LOCAL_APP_CONTAINER} ps -ef | grep sync |wc -l)
        if [ "$syncNum" -eq "0" ] ; then
    	    docker stop ${_LOCAL_APP_CONTAINER} 
            echo -e "HTTP/1.1 503 Service Unavailable\r\n"
            exit 1
    	fi 
   fi

	if [[ ! $_CLUSTER_SIZE ]]; then
  		echo -e "HTTP/1.1 503 Service Unavailable\r\n"
  		 exit 1
    elif [[ $_CLUSTER_SIZE -gt 0  ]] ; then
 	   # wsrep_ready = ON 就可以接受请求
    	if [ "$HOST_SIZE" = "1" ] ; then   
    	      echo -e "HTTP/1.1 200 OK\r\n"
        else
 	        if [ "$_CLUSTER_SIZE" = "1" ]  ; then
 	            other_size=0
         	    for host in $HOST_LIST ; do 
         	        if [ "$HOSTNAME" != "$host" ] ; then
                       #host_out=$(ssh $host docker ps  2>&1 |grep $appContainerName|wc -l 2>&1)
                       #if [[ $host_out > 0 ]] ; then
                        host_out=$(mycliExecStatus $host )
                        OTHER_SIZE=`echo "$host_out" | grep wsrep_cluster_size |awk '{print $2}'  ` 
                        OTHER_STATUS=`echo "$host_out" | grep wsrep_ready |awk '{print $2}'  ` 
                        if [[ "$OTHER_SIZE" -gt "1"  ]] ; then  #其它有二个以上的
                         # echo "OTHER_SIZE=$OTHER_SIZE   OTHER_STATUS=$OTHER_STATUS"
	          			    if [ "$OTHER_STATUS" = "ON" ] ; then
                                echo -e "HTTP/1.1 503 Service Unavailable\r\n"
                                exit 1
	                        fi
	                    elif [[ $OTHER_SIZE -gt  0  ]] ; then  #存在二个以上的为1 独立的集群
                            if [ "$OTHER_STATUS" = "ON" ] ; then 
                                echo -e "HTTP/1.1 503 Service Unavailable\r\n"
                                exit 1
                            fi
         	            fi
         	            #fi
         	        fi
                done
                echo -e "HTTP/1.1 200 OK\r\n"
       		else
      			echo -e "HTTP/1.1 200 OK\r\n"
      		fi
        fi
        #if [ "${ALL_APP/,mycat,/}" != "${ALL_APP}" ] ; then
            
        #fi
        exit 0
    else
      	echo -e "HTTP/1.1 503 Service Unavailable\r\n"
      	exit 1
	fi  
else
	echo -e "HTTP/1.1 503 Service Unavailable\r\n"
	exit 1
fi


exit 1

