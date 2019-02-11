#!/bin/bash

. /etc/bashrc
. $APP_BASE/install/funs.sh

#检查ssh服务端口
sshPort="22"
echo "Check Port: ${sshPort}/tcp"
sshPortStatus=$(testHostPort $(hostname) $sshPort)
if [ "$sshPortStatus" != "open" ]; then
    echo "[ERROR] ${sshPort}/tcp: Connection failed"
    exit 1
fi

#检查重要目录是否存在
needCheckDir="${APP_BASE} ${DATA_BASE} ${LOGS_BASE}"
for dir in ${needCheckDir}; do
    echo "Check directory: $dir"
    sleep 0.2
    if [ ! -d $dir ]; then
        echo "[ERROR] $dir: No such directory"
        exit 1
    fi
done

#检查存储是否挂载
needCheckDir="/infinityfs1"
if [ "$1" != "nocheck" ]; then
    for dir in ${needCheckDir}; do
        echo "Check directory: $dir"
        mountStatus=`findmnt -l | grep infinityfs1`
        if [ -z "$mountStatus" ]; then
            echo "[Warning] $dir: Need to mount storage"
            echo "To skip this check, Use cmd: `basename $0` nocheck"
            exit 1
        fi
    done
fi

# 添加自动关闭
if [ ! -f "/etc/rc1.d/K03sobeyhive_stop" ]; then
echo " #!/bin/bash
/bin/sobeyhive_stop.sh  2>&1
">/etc/init.d/sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc1.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc2.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc3.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc4.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc5.d/K03sobeyhive_stop
    ln -s /etc/init.d/sobeyhive_stop /etc/rc6.d/K03sobeyhive_stop
fi

#==================> 启动所有服务 <=======================
#shostname
echo "systemctl start shostname"
systemctl start shostname >/dev/null 2>&1

#hivedns
echo "systemctl start hivedns"
systemctl start hivedns >/dev/null 2>&1

#deploy
# echo "systemctl start deploy"
# systemctl start deploy >/dev/null 2>&1

#sobeyhive
# echo "systemctl start sobeyhive"
# systemctl start sobeyhive >/dev/null 2>&1

#按启动顺序排列
allApps="zookeeper,keepalived,haproxy,docker,registry,installer,paasman,galaxy,mysql,mycat,mongo,redis,codis,kafka,eagles,eagleslog,logstash,nump,cayman,mamcore,hivecore,hivepmp,sobeyficus_eureka,sobeyficus_config_server,sobeyficus,sobeyficus_admin_ui,kibana,ftengine2,nebula,pronebula,cmserver,cmweb,ingestdbsvr,ingestmsgsvr,ingesttasksvr,mosgateway,jove,otcserver,floatinglicenseserver,pns,infoshare,ntag,articleeditor,h5,infosharecloud,omniocp,omniportal,omnizhihui,wxeditor,search,interview,taskmonitoring,planning,messagecenter,bridge,megateway,mhqapp"
localApps="zookeeper,keepalived,haproxy,docker,installer,nump"

allApps=${allApps//,/ }
localApps=${localApps//,/ }

pingVIP=true
for app in $allApps; do
    sleep 0.2
    [[ "$app" = "installer" ]] && continue
    if [ "`checkLocalApp $app`" = "true" ]; then
        appHome=`getAppHome $app`
        echo -e "\033[1;34m==================================================> starting $app <==================================================\033[0m"
        if [[ "$localApps" =~ "$app" ]]; then
            if [ "$app" = "zookeeper" ]; then
                $ZOOKEEPER_HOME/bin/zkServer.sh start
            else
                echo "systemctl start $app"
                systemctl start $app 2>/dev/null
            fi
        else
            ${appHome}/sbin/start_${app}.sh 2>/dev/null || docker ps -a | awk '{print $NF}' | grep ${app} | xargs docker start 2>/dev/null
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
    docker ps -a | grep 'Exited' | awk '{print $NF}' | xargs docker start 2>/dev/null
else
    start_all_apps "true" "$allApps" "start"
fi

#deploy
echo "systemctl start deploy"
systemctl start deploy >/dev/null 2>&1

#daemon
echo "start_hive_autostart.sh"
start_hive_autostart.sh >/dev/null 2>&1

echo -e "\033[1;34m==================================================> The end <==================================================\033[0m"









