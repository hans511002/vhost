#!/bin/bash

echo "clear env: . ${APP_BASE}/install/00clear_env.sh "
. ${APP_BASE}/install/00clear_env.sh
. /etc/bashrc
bin=$(cd $(dirname $0); pwd)
runCount=`ps -ef | grep ${APP_BASE}/install/hive_auto_start.sh | grep -v grep | awk '{print $2}' | grep -v $$ | wc -l`
if [ "$runCount" -ge "2" ]; then
    echo "hive_auto_start.sh is already running"
    exit 0
fi

hiveAutoStartLogFile="${LOGS_BASE}/hive_auto_start.log"
excludeAutoStartApp=",mysql,"
. ${APP_BASE}/install/funs.sh

count=0
while true ;  do
    sleep 2
    ((count++))
    echo "count=$count"
    # PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
    . ${APP_BASE}/install/00clear_env.sh
    . /etc/bashrc

    #当集群内只剩本机时，continue
    appHosts=(${CLUSTER_HOST_LIST//,/ })
    if [ "${#appHosts[@]}" -gt "1" ];then
        sshStatus=closed
        for host in ${appHosts[@]}; do
            [[ "$host" = "$LOCAL_HOST" ]] && continue
            [[ "`testHostPort $host 22`" = "open" ]] && { sshStatus=open; break; }
        done
        if [ "$sshStatus" != "open" ];then
            kill -9 `ps -ef | grep "${APP_BASE}/*.*/sbin/check_start.sh" | awk '{print $2}'` 2>/dev/null
            continue
        fi
    fi

    ALL_APP=${ALL_APP//,/ }
    deployStatus=`service deploy status >/dev/null 2>&1; echo $?`
    logDate=`date +%Y%m%d%H%M%S`

    if [ "$(($count%43200))" = "0" -o "`du -m $hiveAutoStartLogFile|awk '{print $1}'`" -gt "100" ] ; then
        mv $hiveAutoStartLogFile $hiveAutoStartLogFile-$logDate
        nohup gzip $hiveAutoStartLogFile-$logDate &
    fi

    if [ "$deployStatus" != "0" -o "$ALL_APP" = "${ALL_APP//installer/}" ] ; then
        if [ "$(($count%5))" = "0" ] ; then
            echo "`date`: checkHostHealthy " >> $hiveAutoStartLogFile
            checkHostHealthy >> $hiveAutoStartLogFile
        fi

        if [ "$(($count%43200))" = "0" ] ; then
            KEEP_SNAPSLOGS_COUNT="${KEEP_SNAPSLOGS_COUNT:=20}"
            nohup $ZOOKEEPER_HOME/bin/zkCleanup.sh -n $KEEP_SNAPSLOGS_COUNT >> ${LOGS_BASE}/zookeeper/clean.log 2>&1 &
            mv ${LOGS_BASE}/zookeeper/clean.log ${LOGS_BASE}/zookeeper/clean.log-$logDate
            echo "gzip ${LOGS_BASE}/zookeeper/clean.log-$logDate" >> $hiveAutoStartLogFile
            nohup gzip ${LOGS_BASE}/zookeeper/clean.log-$logDate &
            nohup $bin/clean_logs.sh $LOGS_BASE 15 >> $hiveAutoStartLogFile 2>&1 &
        fi
    fi

    if [ "${dns_hosts/$LOCAL_HOST/}" != "${dns_hosts}" -a -f $bin/dns_ddns.sh ] ; then
        nohup $bin/dns_ddns.sh > /tmp/dns_ddns.log >> $hiveAutoStartLogFile 2>&1 &
    fi

    if [ "$(($count%5))" = "0" -a -f "$bin/check_docker_container.sh" ] ; then
        ckdockerConPids=`ps -ef|grep "check_docker_container.sh"|grep -v grep |awk '{print $2}'`
        if [ "$ckdockerConPids" != "" ] ; then
            echo $ckdockerConPids|xargs kill -9
        fi
        echo "`date`: exec $bin/check_docker_container.sh" >> $hiveAutoStartLogFile
        nohup $bin/check_docker_container.sh > /dev/null 2>&1 &
    fi

    #if docker命令卡住后超过一定数量时，continue
    dockerCMD=`ps -ef | grep -E 'docker ps|docker start|docker stop|docker restart'| wc -l`
    [[ "$dockerCMD" -gt "10" ]] && continue

    echo "`date`: ALL_APP=$ALL_APP " >> $hiveAutoStartLogFile
    for APP in $ALL_APP ; do
        echo -n "check $APP: " >> $hiveAutoStartLogFile
        if [ "$excludeAutoStartApp" != "${excludeAutoStartApp//,$APP,/}"  ] ; then
            if [ "$deployStatus" = "0" ] ; then
                continue
            fi
        fi
        appHome=`echo "$APP" |awk '{printf("%s_HOME",toupper($0))}'`
        APP_HOME=`env|grep -E ^$appHome|awk -F= '{print $2}'`
        if [ -z "$APP_HOME" -o ! -d "$APP_HOME" ] ; then
            echo "$APP: Not install completed!" >> $hiveAutoStartLogFile
            continue
        fi
        echo "$appHome=$APP_HOME" >> $hiveAutoStartLogFile
        if [ -f "$APP_HOME/sbin/auto_start.sh" ] ; then
            if [ -z "`ps -ef | grep $APP_HOME/sbin/check_start.sh | grep -v grep`" ]; then
                #logrotate apps auto_start.log
                if [ "$(($count/43200))" -ge "1" ] ; then
                    mv ${LOGS_BASE}/$APP/auto_start.log ${LOGS_BASE}/$APP/auto_start.log-$logDate
                    echo "gzip ${LOGS_BASE}/$APP/auto_start.log-$logDate" >> $hiveAutoStartLogFile
                    nohup gzip ${LOGS_BASE}/$APP/auto_start.log-$logDate &
                fi
                echo "exec $APP_HOME/sbin/auto_start.sh" >> $hiveAutoStartLogFile
                nohup $APP_HOME/sbin/auto_start.sh >> ${LOGS_BASE}/$APP/auto_start.log 2>&1 &
            fi
        fi
    done
    echo "" >> $hiveAutoStartLogFile
done

