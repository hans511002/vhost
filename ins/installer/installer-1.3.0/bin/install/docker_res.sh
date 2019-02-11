#!/bin/bash
INSBIN=`dirname "${BASH_SOURCE-$0}"`
INSBIN=`cd "$INSBIN">/dev/null; pwd`


#backup env
cpuCountOld=$cpuCount
memCountOld=$memCount
appNameOld=$appName

#get cpu/memory
cpuCount=`grep -c "processor.*:.*[0-9]" /proc/cpuinfo`
memCount=`grep MemTotal /proc/meminfo |awk '{print $2}'` #单位: Kb
memCount=$(($memCount/1024/1024*1000)) #单位: Mb
dockerVersion=`docker version 2>/dev/null|grep Version|sed -e "s|.*Version: ||" -e "s|, .*||" -e "s|\..*||" | tail -n 1|awk '{print $1}'`
dockerVersion="${dockerVersion:=17}"

if [ "$dockerVersion" -gt "1" ] ; then
    #get apps
    apps=${ALL_APP//,/ }
    for appName in $apps; do
        #cpu
        if [ $cpuCount -le 8 ]; then
            cpuLimit="$(($cpuCount*50/100))"
        elif [ $cpuCount -le 16 ]; then
            cpuLimit="$(($cpuCount*40/100))"
        elif [ $cpuCount -le 32 ]; then
            cpuLimit="$(($cpuCount*30/100))"
        else
            cpuLimit="$(($cpuCount*20/100))"
        fi

        #memory
        if [ $memCount -le 20000 ]; then
            memLimit="$(($memCount*80/100))m"
        elif [ $memCount -le 60000 ]; then
            memLimit="$(($memCount*30/100))m"
        elif [ $memCount -le 120000 ]; then
            memLimit="$(($memCount*25/100))m"
        else
            memLimit="$(($memCount*20/100))m"
        fi
        #RESOURCES ENV
        appStr=`echo $(echo $appName|awk '{print toupper($0)}')_RESOURCES`
        export $appStr="--cpus $cpuLimit --memory $memLimit"
    done
else
    if [ -f "$INSBIN/docker_res_old.sh" ] ; then
        apps=${ALL_APP//,/ }
        for appName in $apps; do
            appStr=`echo $(echo $appName|awk '{print toupper($0)}')_RESOURCES`
            #echo "$appStr="
            export $appStr=""
        done
        . $INSBIN/docker_res_old.sh
    fi 
fi


#restore env
cpuCount=$cpuCountOld
memCount=$memCountOld
appName=$appNameOld

