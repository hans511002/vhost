#!/bin/bash

. /etc/bashrc
. $APP_BASE/install/funs.sh
clusterHosts=${CLUSTER_HOST_LIST//,/ }

#==================> 停止所有服务 <=======================
#sobeyhive
for host in ${clusterHosts}; do
    echo "$host ===> systemctl stop sobeyhive"
    ssh $host systemctl stop sobeyhive >/dev/null 2>&1
done

#deploy
for host in ${clusterHosts}; do
    echo "$host ===> systemctl stop deploy"
    ssh $host systemctl stop deploy >/dev/null 2>&1
done

#shostname
for host in ${clusterHosts}; do
    echo "$host ===> systemctl stop shostname"
    ssh $host systemctl stop shostname >/dev/null 2>&1
done

#hivedns
for host in ${clusterHosts}; do
    echo "$host ===> systemctl stop hivedns"
    ssh $host systemctl stop hivedns >/dev/null 2>&1
done

#daemon
for host in ${clusterHosts}; do
    echo "$host ===> stop_hive_autostart.sh"
    ssh $host stop_hive_autostart.sh >/dev/null 2>&1
done

#按照启动顺序排列
allApps="zookeeper,keepalived,haproxy,docker,registry,installer,paasman,galaxy,mysql,mycat,mongo,redis,codis,kafka,eagles,eagleslog,logstash,nump,cayman,mamcore,hivecore,hivepmp,sobeyficus_eureka,sobeyficus_config_server,sobeyficus,sobeyficus_admin_ui,kibana,ftengine2,nebula,pronebula,cmserver,cmweb,ingestdbsvr,ingestmsgsvr,ingesttasksvr,mosgateway,jove,otcserver,floatinglicenseserver,pns,infoshare,ntag,articleeditor,h5,infosharecloud,omniocp,omniportal,omnizhihui,wxeditor,search,interview,taskmonitoring,planning,messagecenter,bridge,megateway,mhqapp,archivemanager,saas"
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
    appHome=`getAppHome $app`
    if [ "`check_app $app`" = "true" ]; then
        #other containers
        if [ "$app" = "docker" ]; then
            echo -e "\033[1;34m==================================================> stopping other containers <==================================================\033[0m"
            for host in ${docker_hosts//,/ }; do
                ssh $host "docker ps -a | grep 'Up' | awk '{print \$NF}' | xargs docker stop 2>/dev/null"
                sleep 0.5
            done
        fi

        echo -e "\033[1;34m==================================================> stopping $app <==================================================\033[0m"
        if [[ "$localApps" =~ "$app" ]]; then
            if [ "$app" = "zookeeper" ]; then
                runAppOnFisrtHost $app "${appHome}/sbin/stop-zk.sh"
            else
                cmdCTL="systemctl stop $app"
                runHOSTCMD $app "$cmdCTL"
            fi
        else
            cmdCTL="${appHome}/sbin/stop_${app}_cluster.sh"
            runAppOnFisrtHost $app "$cmdCTL"
        fi
    fi
done

echo -e "\033[1;34m==================================================>  The end <==================================================\033[0m"












