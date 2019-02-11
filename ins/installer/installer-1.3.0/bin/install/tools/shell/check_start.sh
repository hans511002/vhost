#!/bin/bash
#check script
#appName/checkURL/waitTime need modify by different apps

#应用名称
appName=cmserver

#检测地址（根据应用修改,仅适用于http mode）
checkURL="http://$(hostname):9022/CMApi/api/basic/account/testconnect/"

#容器运行延时检测，单位：秒（根据服务启动时长修改）
waitTime=60

[[ $ALL_APP =~ $appName ]] || { echo "$ALL_APP !=~ $appName"; exit 1; }
appHome=`env | grep "$(echo $appName | awk '{print toupper($0)}')_HOME" | awk -F '=' '{print $NF}'`
appVersion=`echo $appHome | awk -F '-' '{print $NF}'`
containerName=${appName}-$(hostname)

if [ -z "`docker ps -a | grep $containerName`" ]; then
    echo "${APP_BASE}/install/${appName}/${appName}-${appVersion}-run.sh"
    ${APP_BASE}/install/${appName}/${appName}-${appVersion}-run.sh
fi

if [ -z "`docker ps | grep $containerName`" ]; then
    echo "docker start $containerName"
    docker start $containerName
fi

#时间戳对比，容器运行时间小于延时检测时退出
containerStatus=`docker inspect -f '{{.State.Status}}' $containerName`
if [ "$containerStatus" = "running" ]; then
    containerStartedAt=`docker inspect -f '{{.State.StartedAt}}' $containerName`
    
    if [ -n "$containerStartedAt" ]; then
        startTimestamp=`date -d "$containerStartedAt" +%s`
        currentTimestamp=`date +%s`
        
        if [ "$((${currentTimestamp}-${startTimestamp}))" -le "$waitTime" ];then
            echo "$containerName Uptime: $((${currentTimestamp}-${startTimestamp})) -le $waitTime"
            exit 0
        fi
    fi
else
    echo "$containerName: containerStatus=$containerStatus"
    exit 1
fi

#连续三次检测失败才重启容器（避免网络或其他问题导致某次检测失败）
tryTimes=0
for i in {1..3}; do
    httpCode=`curl -m 2 -o /dev/null -s -w %{http_code}"\n" ${checkURL}`
    if [ "$httpCode" = "200" ]; then
        break
    else
        ((tryTimes++))
    fi
    sleep 2
done

if [ "$tryTimes" = "3" ]; then
    echo "tryTimes=${tryTimes}: docker restart $containerName"
    docker restart $containerName
fi

