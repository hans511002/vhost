#!/bin/bash

. /etc/bashrc
. $APP_BASE/install/funs.sh
clusterHosts=${CLUSTER_HOST_LIST//,/ }

#检查ssh服务端口
sshPort="22"
for host in ${clusterHosts}; do
    echo "$host ===> Check Port: ${sshPort}/tcp"
    sshPortStatus=$(testHostPort $host $sshPort)
    if [ "$sshPortStatus" != "open" ]; then
        echo "[ERROR] $host ===> ${sshPort}/tcp: Connection failed"
        exit 1
    fi
done

#检查重要目录是否存在
needCheckDir="${APP_BASE} ${DATA_BASE} ${LOGS_BASE}"
for host in ${clusterHosts}; do
    for dir in ${needCheckDir}; do
        echo "$host ===> Check directory: $dir"
        sleep 0.2
        if [ ! -d $dir ]; then
            echo "[ERROR] $host ===> $dir: No such directory"
            exit 1
        fi
    done
done

#检查存储是否挂载
needCheckDir="/infinityfs1"
if [ "$1" != "nocheck" ]; then
    for host in ${clusterHosts}; do
        for dir in ${needCheckDir}; do
            echo "$host ===> Check directory: $dir"
            mountStatus=`ssh $host "findmnt -l | grep infinityfs1"`
            if [ -z "$mountStatus" ]; then
                echo "[Warning] $host ===> $dir: Need to mount storage"
                echo "To skip this check, Use cmd: `basename $0` nocheck"
                exit 1
            fi
        done
    done
fi

if [ "$1" = "nocheck" ]; then
    shift
fi

#检查时时钟是否同步(10s)
declare -A hostTime
for host in ${clusterHosts}; do
	echo "$host ===> `date`"
    DT="`ssh $host "date +%s"`"
	hostTime[$host]=${DT}
done

allTime=(${hostTime[@]})
maxTime=${allTime[0]}
for time in ${allTime[@]}; do
	if [ $time -gt $maxTime ]; then
		maxTime=$time
	fi
done

minTime=${allTime[0]}
for time in ${allTime[@]}; do
	if [ $time -lt $minTime ]; then
		minTime=$time
	fi
done

if [ "$(($maxTime-$minTime))" -gt "10" ]; then
    echo "[ERROR] Cluster time is out of sync, please adjust and retry"
    exit 1
fi

#添加自动关闭
if [ ! -f "/etc/rc1.d/K03sobeyhive_stop" ] ; then
echo " #!/bin/bash
/bin/sobeyhive_stop.sh  2>&1
">/etc/init.d/sobeyhive_stop
    chmod a+x /etc/init.d/sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc1.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc2.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc3.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc4.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc5.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc6.d/K03sobeyhive_stop
fi

#==================> 启动所有服务 <=======================
#shostname
for host in ${clusterHosts}; do
    echo "$host ===> systemctl start shostname"
    ssh $host systemctl start shostname >/dev/null 2>&1
done

#hivedns
for host in ${clusterHosts}; do
    echo "$host ===> systemctl start hivedns"
    ssh $host systemctl start hivedns >/dev/null 2>&1
done

#deploy
# for host in ${clusterHosts}; do
    # echo "$host ===> systemctl start deploy"
    # ssh $host systemctl start deploy >/dev/null 2>&1
# done

#sobeyhive
# for host in ${clusterHosts}; do
    # echo "$host ===> systemctl start sobeyhive"
    # ssh $host systemctl start sobeyhive >/dev/null 2>&1
# done

#按启动顺序排列
allApps="zookeeper,keepalived,haproxy,docker,registry,installer,paasman,galaxy,mysql,mycat,mongo,redis,codis,kafka,eagles,eagleslog,logstash,nump,cayman,mamcore,hivecore,hivepmp,sobeyficus_eureka,sobeyficus_config_server,sobeyficus,sobeyficus_admin_ui,kibana,ftengine2,nebula,pronebula,cmserver,cmweb,ingestdbsvr,ingestmsgsvr,ingesttasksvr,mosgateway,jove,otcserver,floatinglicenseserver,pns,infoshare,ntag,articleeditor,h5,infosharecloud,omniocp,omniportal,omnizhihui,wxeditor,search,interview,taskmonitoring,planning,messagecenter,bridge,megateway,mhqapp,archivemanager,saas"
localApps="zookeeper,keepalived,haproxy,docker,installer,nump"

allApps=${allApps//,/ }
localApps=${localApps//,/ }

pingVIP=true
for app in $allApps; do
    sleep 0.2
    [[ "$app" = "installer" ]] && continue
    appHome=`getAppHome $app`
    if [ "`check_app $app`" = "true" ]; then
        echo -e "\033[1;34m==================================================> starting $app <==================================================\033[0m"
        if [[ "$localApps" =~ "$app" ]]; then
            if [ "$app" = "zookeeper" ]; then
                runAppOnFisrtHost $app "${appHome}/sbin/start-zk.sh"
            else
                cmdCTL="systemctl start $app"
                runHOSTCMD $app "$cmdCTL"
            fi
        else
            cmdCTL="${appHome}/sbin/start_${app}_cluster.sh"
            runAppOnFisrtHost $app "$cmdCTL"
        fi
        #判断是否有check脚本,有则执行
        checkScript=`getCheckScript $app`
        if [ -n "$checkScript" ]; then
            sleep 2 && runAppOnFisrtHost $app "${checkScript}"
        fi
        #ping $NEBULA_VIP
        if [ "$pingVIP" = "true" ]; then
            [[ "$app" = "keepalived" ]] || [[ $ALL_APP != *keepalived* ]] && 
            echo -e "\033[1;34m==================================================> ping \$NEBULA_VIP <==================================================\033[0m" &&
            { [[ "`ping -W 10 -c 10 $NEBULA_VIP >/dev/null 2>&1; echo $?`" = "0" ]] && pingVIP=false || { echo "[ERROR]: ping $NEBULA_VIP"; exit 1; } }
        fi
    fi
done

#other containers
if [ "$1" = "all" ]; then
    echo -e "\033[1;34m==================================================> starting other containers <==================================================\033[0m"
    for host in ${docker_hosts//,/ }; do
        ssh $host "docker ps -a | grep 'Exited' | awk '{print \$NF}' | xargs docker start 2>/dev/null"
        sleep 0.2
    done
else
    start_all_apps "true" "$allApps" "start"
fi

#deploy
for host in ${clusterHosts}; do
    echo "$host ===> systemctl start deploy"
    ssh $host systemctl start deploy >/dev/null 2>&1
done

#daemon
for host in ${clusterHosts}; do
    echo "$host ===> start_hive_autostart.sh"
    ssh $host start_hive_autostart.sh >/dev/null 2>&1
done

echo -e "\033[1;34m==================================================> The end <==================================================\033[0m"









