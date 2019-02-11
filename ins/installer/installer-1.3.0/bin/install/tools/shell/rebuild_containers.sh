#!/bin/bash
#author: hehaiqiang
#修改集群所有节点
#不带参数：根据目前已run容器，删除并重建
#带参数：all，不删除容器，不判断是否已run，根据$ALL_APP执行所有容器run.sh

. /etc/bashrc
appHosts=$(cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//')

needCheckDir="${APP_BASE} ${DATA_BASE} ${LOGS_BASE}"
for host in ${appHosts}; do
    for dir in ${needCheckDir}; do
        echo "$host ===> Check directory: $dir"
        sleep 0.2
        if [ ! -d $dir ]; then
            echo "[ERROR] $host ===> $dir: No such directory"
            exit 1
        fi
    done
done

for host in ${appHosts}; do
    echo "$host ===> Check the service status..."
    dockerStatus=`ssh $host "systemctl status docker >/dev/null 2>&1"; echo $?`
    if [ "$dockerStatus" = "0" ]; then
        echo "$host ===> You must stop all app. use cmd: sobeyhive_stop_all.sh"
        exit 1
    fi
done

stop_hive_autostart.sh all >/dev/null 2>&1

for host in ${appHosts}; do
    dockerStatus=`ssh $host "systemctl start docker >/dev/null 2>&1"; echo $?`
    if [ "$dockerStatus" != "0" ]; then
        echo "$host ===> exec failed: systemctl start docker"
        exit 1
    fi
done

echo "checking, please wait..."
sleep 5

for host in $appHosts; do

    appLists=`ssh $host "echo \${ALL_APP//,/ }"`
    containerLists=$(ssh $host "docker ps -a | grep -v 'NAMES' | awk '{print \$NF}' | awk -F '-' '{print \$1}' | uniq | xargs echo")
    echo "appLists=$appLists"
    echo "containerLists=\"$containerLists\""

    for app in $appLists; do

        if [ "$1" = "all" ]; then

            [[ "kibana" =~ "$app" ]] && continue
            appHomeStr=`echo $app | awk '{print toupper($0)}'`_HOME
            AppVersion=`ssh $host "env | grep $appHomeStr" | awk -F '-' '{print $NF}'`
            AppRunScripts=`ssh $host "find \${APP_BASE}/install/$app/ -name '$app-*$AppVersion-run.sh'"`
            appUserStr="${app}_user"
            appUser=`ssh $host "env | grep $appUserStr" | awk -F '=' '{print $NF}'`

            if [ -z "AppRunScripts" ]; then
                continue
            fi

            if [ -z "appUser" ]; then
                appUser="root"
            fi

            for runScript in $AppRunScripts; do
                echo "$host: $runScript"
                ssh $host "runuser -l $appUser -c \"${runScript}\"" 2>/dev/null
            done

            sleep 2

            appcontainers=`ssh $host "docker ps -a" | awk '{print $NF}' | grep ${app}- | sort | xargs echo`
            for cnt in $appcontainers; do
                echo "$host: docker stop $cnt"
                ssh $host "docker stop $cnt"
            done

        else

            [[ "$containerLists" =~ "$app" ]] || continue
            appHomeStr=`echo $app | awk '{print toupper($0)}'`_HOME
            AppVersion=`ssh $host "env | grep $appHomeStr" | awk -F '-' '{print $NF}'`
            AppRunScripts=`ssh $host "find \${APP_BASE}/install/$app/ -name '$app-*$AppVersion-run.sh'"`
            appUserStr="${app}_user"
            appUser=`ssh $host "env | grep $appUserStr" | awk -F '=' '{print \$NF}'`

            if [ -z "AppRunScripts" ]; then
                continue
            fi

            if [ -z "appUser" ]; then
                appUser="root"
            fi

            appcontainers=`ssh $host "docker ps -a" | awk '{print $NF}' | grep ${app}- | sort | xargs echo`
            for cnt in $appcontainers; do
                echo "$host: docker rm -f $cnt"
                ssh $host "docker rm -f $cnt"
            done

            for runScript in $AppRunScripts; do
                echo "$host: $runScript"
                ssh $host "runuser -l $appUser -c \"${runScript}\""
            done

            sleep 2

            appcontainers=`ssh $host "docker ps -a" | awk '{print $NF}' | grep ${app}- | sort | xargs echo`
            for cnt in $appcontainers; do
                echo "$host: docker stop $cnt"
                ssh $host "docker stop $cnt"
            done
        fi
    done
done









