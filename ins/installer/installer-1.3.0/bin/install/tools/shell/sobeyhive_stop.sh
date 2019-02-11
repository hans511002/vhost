#!/bin/bash

. /etc/bashrc
. $APP_BASE/install/funs.sh

#==================> 停止所有服务 <=======================
#sobeyhive
echo "systemctl stop sobeyhive"
systemctl stop sobeyhive >/dev/null 2>&1

#deploy
echo "systemctl stop deploy"
systemctl stop deploy >/dev/null 2>&1

#shostname
echo "systemctl stop shostname"
systemctl stop shostname >/dev/null 2>&1

#hivedns
echo "systemctl stop hivedns"
systemctl stop hivedns >/dev/null 2>&1

#daemon
echo "stop_hive_autostart.sh"
stop_hive_autostart.sh >/dev/null 2>&1


#按照启动顺序排列
allApps="zookeeper,keepalived,haproxy,docker,registry,installer,paasman,galaxy,mysql,mycat,mongo,redis,codis,kafka,eagles,eagleslog,logstash,nump,cayman,mamcore,hivecore,hivepmp,sobeyficus_eureka,sobeyficus_config_server,sobeyficus,sobeyficus_admin_ui,kibana,ftengine2,nebula,pronebula,cmserver,cmweb,ingestdbsvr,ingestmsgsvr,ingesttasksvr,mosgateway,jove,otcserver,floatinglicenseserver,pns,infoshare,ntag,articleeditor,h5,infosharecloud,omniocp,omniportal,omnizhihui,wxeditor,search,interview,taskmonitoring,planning,messagecenter,bridge,megateway,mhqapp"
localApps="zookeeper,keepalived,haproxy,docker,installer,nump"

allApps=${allApps//,/ }
localApps=${localApps//,/ }

#逆序allApps/localApps
for app in $allApps; do
    revApps01="$app $tmpApps01"
    tmpApps01=$revApps01
done
allApps=$revApps01

for app in $localApps; do
    revApps02="$app $tmpApps02"
    tmpApps02=$revApps02
done
localApps=$revApps02

for app in $allApps; do
    sleep 0.2
    [[ "$app" = "installer" ]] && continue
    if [ "`checkLocalApp $app`" = "true" ]; then
        appHome=`getAppHome $app`
        #other containers
        if [ "$app" = "docker" ]; then
            echo -e "\033[1;34m==================================================> stopping other containers <==================================================\033[0m"
            docker ps -a | grep 'Up' | awk '{print $NF}' | xargs docker stop 2>/dev/null
        fi

        echo -e "\033[1;34m==================================================> stopping $app <==================================================\033[0m"
        if [[ "$localApps" =~ "$app" ]]; then
            if [ "$app" = "zookeeper" ]; then
                $ZOOKEEPER_HOME/bin/zkServer.sh stop
            else
                echo "systemctl stop $app"
                systemctl stop $app 2>/dev/null
            fi
        else
            ${appHome}/sbin/stop_${app}.sh 2>/dev/null || docker ps -a | awk '{print $NF}' | grep ${app} | xargs docker stop 2>/dev/null
        fi
    fi
done

echo -e "\033[1;34m==================================================>  The end <==================================================\033[0m"









