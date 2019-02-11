#!/bin/bash     

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

RUNED=`ps -ef|grep "$BIN/check_docker_container.sh"|grep -v grep|grep "/bin/bash" |wc -l `
if [ "$RUNED" != "" ]; then
    if [ "$RUNED" -gt 2  ]; then
    echo "ruuned $RUNED"
       exit 0
    fi
fi

ALL_APP=${ALL_APP//,/ }

mkdir -p $LOGS_BASE/docker
containersListFile=$LOGS_BASE/docker/docker_containers
LOG_DATE=`date "+%Y%m%d"`
LOG_FILE="${LOGS_BASE}/docker/check_docker_container.log.$LOG_DATE"

DOCKER_CONTAINERS=`docker ps -a |grep $HOSTNAME| grep -v "registry."|grep -v test |grep -v "dynamic-ha-" | grep -v CONTAINER|awk '{print $NF}'`
if [ -f  $containersListFile ] ; then
    OLD_DOCKER_CONTAINERS=`cat $containersListFile`
else
    echo "$DOCKER_CONTAINERS" > $containersListFile
    exit 0
fi

declare -A DOCKER_CONTAINERS_MAP
for key in $DOCKER_CONTAINERS; do
    if [ -z "${DOCKER_CONTAINERS_MAP[$key]}" ]; then
        DOCKER_CONTAINERS_MAP[$key]=1
    else
        let DOCKER_CONTAINERS_MAP[$key]++
    fi
done

declare -A OLD_DOCKER_CONTAINERS_MAP
for key in $OLD_DOCKER_CONTAINERS; do
    if [ -z "${OLD_DOCKER_CONTAINERS_MAP[$key]}" ]; then
        OLD_DOCKER_CONTAINERS_MAP[$key]=1
    else
        let OLD_DOCKER_CONTAINERS_MAP[$key]++
    fi
done

declare -A NO_DOCKER_CONTAINERS_MAP
for key in $OLD_DOCKER_CONTAINERS; do
    if [ -z "${DOCKER_CONTAINERS_MAP[$key]}" ]; then
        NO_DOCKER_CONTAINERS_MAP[$key]=1
    fi
done

NEW_DOCKER_CONTAINERS=""
for key in $DOCKER_CONTAINERS; do
    if [ -z "${OLD_DOCKER_CONTAINERS_MAP[$key]}" ]; then
        if [ "$NEW_DOCKER_CONTAINERS" = "" ] ; then
            NEW_DOCKER_CONTAINERS="$key"
        else
            NEW_DOCKER_CONTAINERS="$key
$NEW_DOCKER_CONTAINERS"
        fi
        
    fi
done

if [ "$NEW_DOCKER_CONTAINERS" != "" ] ; then
    echo "`date` new container=$NEW_DOCKER_CONTAINERS"  | tee -a ${LOG_FILE} 
    echo "$NEW_DOCKER_CONTAINERS">>$containersListFile
fi
allDelDks="${!NO_DOCKER_CONTAINERS_MAP[@]}"
echo "allDelDks=$allDelDks"
if [ "$allDelDks" = "" ] ; then
    exit 0
fi
echo "null container=${!NO_DOCKER_CONTAINERS_MAP[@]}" 
for app_docker in ${!NO_DOCKER_CONTAINERS_MAP[@]}; do
    echo "`date` begin to recreate container $app_docker" | tee -a ${LOG_FILE}
    app_name=${app_docker//-*/}
    appHome=`echo "$app_name" |awk  '{printf("%s_HOME",toupper($1))}' `
    appName=`echo "$app_name" |awk  '{printf("%s",tolower($1))}' `
    APP_HOME=`env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
    echo "appHome=$appHome appName=$appName"  | tee -a ${LOG_FILE} 

    echo "APP_HOME=$APP_HOME"  | tee -a ${LOG_FILE}
    if [ "$APP_HOME" = ""  ] ; then
        appHome=`echo "$app_name" |awk  '{printf("%s_DOCKER_HOME",toupper($1))}' `
	    APP_HOME=`env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
	    if [ "$APP_HOME" = ""  ] ; then
 		    echo " app $app_docker not install completed"  | tee -a ${LOG_FILE}
		    continue
        fi
    fi
    appVer=`echo "$APP_HOME" |awk -F- '{print $2}' `
    echo "$appHome=$APP_HOME"  | tee -a ${LOG_FILE}
    if [ -d "$BIN/$appName" ] ; then
        runShell=`ls $BIN/$appName/$appName-*$appVer-run.sh`
        appUser=`env|grep ${appName}_user|sed -e "s|${appName}_user=||"`
        YYYYMM="`date "+%Y%m"`"
        for run in $runShell ; do
            echo "`date` exec: $run "  | tee -a ${LOG_FILE}
            RES=1
            DATETIME="`date "+%s"`000"
            if [ "$appUser" != "" -a "$appUser" != "root" ] ; then
                echo "su $appUser  $run  | tee -a ${LOG_FILE}"
                 RESMSG=`su $appUser $run` 
            else
                 RESMSG=`$run`
            fi
            RES=$?
            echo "$RESMSG"   | tee -a ${LOG_FILE}
            echo "{\"appName\":\"$appName\",\"res\":$RES,\"order\":\"rerun\",\"dateTime\":$DATETIME,\"command\":\"$run\",\"hostName\":\"$HOSTNAME\",\"msg\":\"$RESMSG\",\"user\":\"auto\"}">>${LOGS_BASE}/installer/app_opt.log.$YYYYMM 
        done
    else
        echo "`date` docker container $app_docker install shell home \"$BIN/$appName\" not exists"  | tee -a ${LOG_FILE}
        sed -i -e "s/$app_docker.*//" $containersListFile
    fi
done
