#!/usr/bin/env bash
# 
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
for i in /etc/profile.d/*.sh; do
    if [ -r "$i" ]; then
        if [ "$PS1" ]; then
            . "$i"
        else
            . "$i" >/dev/null
        fi
    fi
done

testProcess(){
    kill -0 $1 2>/dev/null
    if [ "$?" = "0" ] ; then
        echo true
    else
        echo false
    fi
}
. ${APP_BASE}/install/funs.sh

COMMAND=$1
shift


DEPLOY_PID=
start(){
count=0

startDate=`date +%Y%m%d`

while true ;  do
    count=0
    export count
    runed=`ps -ef|grep Deployactor|grep -v grep |grep "com.sobey.jcg.sobeyhive.deployactor.Deployactor"  |grep "Deployactor -start"| wc -l `
    if [ "$runed" -ne "1" ] ; then
        if [ "${INSTALLER_HOME}" != "" -a  -e "${INSTALLER_HOME}" ] ; then
            echo "nohup ${INSTALLER_HOME}/sbin/installer deploy start 2>&1 >/dev/null 2>&1 "
            nohup ${INSTALLER_HOME}/sbin/installer deploy start  2>&1 >/dev/null 2>&1 & 
            startDate=`date +%Y%m%d`
            sleep 2
            DEPLOY_PID=`ps -ef|grep Deployactor|grep -v grep |grep "com.sobey.jcg.sobeyhive.deployactor.Deployactor"  |grep "Deployactor -start"|awk '{print $2}' `
        else
            echo "not sucess install deployer"
            sleep 2
            . ${APP_BASE}/install/funs.sh
            continue
        fi
    else
        DEPLOY_PID=`ps -ef|grep Deployactor|grep -v grep |grep "com.sobey.jcg.sobeyhive.deployactor.Deployactor"  |grep "Deployactor -start"|awk '{print $2}' `
    fi
    sleep 2
    dayNo=`date +%Y%m%d`
    checkLogFile="${LOGS_BASE}/installer/checkHostHealthy.log.$dayNo"
    checkHostHealthy "notckdata" | tee -a $checkLogFile 2>&1
    echo "DEPLOY_PID=$DEPLOY_PID"
    if [ "$DEPLOY_PID" = "" ] ; then
        continue
    fi
    while [ `testProcess $DEPLOY_PID` = "true" ] ;  do
        sleep 2
        ((count++))
        if [ "`expr $count % 300 ` " -eq "0" ] ; then
            . ${APP_BASE}/install/funs.sh
            dayNo=`date +%Y%m%d`
            checkHostHealthy | tee -a $checkLogFile 2>&1
            _startDate=`date +%Y%m%d`
            #if [ "$_startDate" -gt "$startDate" ] ; then
            #    KEEP_SNAPSLOGS_COUNT="${KEEP_SNAPSLOGS_COUNT:=10}"
            #    echo "$ZOOKEEPER_HOME/bin/zkCleanup.sh -n $KEEP_SNAPSLOGS_COUNT  2>&1 " | tee -a $checkLogFile
            #    $ZOOKEEPER_HOME/bin/zkCleanup.sh -n $KEEP_SNAPSLOGS_COUNT  2>&1  | tee -a $checkLogFile
            #    echo "exec: ${APP_BASE}/install/clean_logs.sh $LOGS_BASE 10 " | tee -a $checkLogFile 
            #    ${APP_BASE}/install/clean_logs.sh $LOGS_BASE 10  |grep 'rm -rf' | tee -a $checkLogFile
            #    sleep 60
            #    kill -9 $DEPLOY_PID
            #fi
            startDate=$_startDate
        fi
        if [ "`expr $count % 10 ` " -eq "0" ] ; then
            HHMM=`date +%H%M`
            if [ "$HHMM" = "2300" ] ; then
                KEEP_SNAPSLOGS_COUNT="${KEEP_SNAPSLOGS_COUNT:=10}"
                echo "$ZOOKEEPER_HOME/bin/zkCleanup.sh -n $KEEP_SNAPSLOGS_COUNT  2>&1 " | tee -a $checkLogFile
                $ZOOKEEPER_HOME/bin/zkCleanup.sh -n $KEEP_SNAPSLOGS_COUNT  2>&1  | tee -a $checkLogFile
                echo "exec: ${APP_BASE}/install/clean_logs.sh $LOGS_BASE 10 " | tee -a $checkLogFile 
                ${APP_BASE}/install/clean_logs.sh $LOGS_BASE 10  |grep 'rm -rf' | tee -a $checkLogFile
                sleep 60
                kill -9 $DEPLOY_PID
            fi
        fi
    done
done
}

restart(){
stop $@
start
}

stop(){
MAINPID=$1
echo "MAINPID=$MAINPID"
if [ "$MAINPID" != "" ] ; then
kill -2 $MAINPID 2>/dev/null
fi
DEPLOY_PID=`ps -ef|grep Deployactor|grep -v grep |grep "com.sobey.jcg.sobeyhive.deployactor.Deployactor"  |grep "Deployactor -start"|awk '{print $2}' `
if [ "$DEPLOY_PID" != "" ] ; then
    kill -USR2 $DEPLOY_PID  2>/dev/null
    sleep 1
    kill -9 $DEPLOY_PID 2>/dev/null
fi 
kill -9 $MAINPID 2>/dev/null
rm -rf /hs_err_pid*
}
status(){
DEPLOY_PID=`ps -ef|grep Deployactor|grep -v grep |grep "com.sobey.jcg.sobeyhive.deployactor.Deployactor"  |grep "Deployactor -start"|awk '{print $2}' `
if [ "$DEPLOY_PID" != "" ] ; then
    echo "deploy is running pid:$DEPLOY_PID"
    exit 0
else
    echo "deploy is exited"
    exit 1
fi
}
#echo "COMMAND=$COMMAND"
if [ "$COMMAND" = "start" ] ; then
start
elif [ "$COMMAND" = "restart" ] ; then
restart
elif [ "$COMMAND" = "stop" ] ; then
stop
else
status
fi

