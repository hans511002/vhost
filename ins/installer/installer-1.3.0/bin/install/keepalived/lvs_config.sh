#! /bin/bash

if [ $# -lt 2 ] ; then
  echo "usetag:keepalived_lvs.sh LOCAL_IP LOCAL_HOST"
  exit 1
fi
. /etc/bashrc
. $APP_BASE/install/funs.sh

LOCAL_IP=$1
LOCAL_HOST=$2


install_ha=`isInstallHaproxy`
if [ "$install_ha" != "true" ] ; then
    echo "not install haproxy"
    exit 1
fi


destFile="/etc/keepalived/lvs.conf"
netTransFile="$APP_BASE/install/iptable_trans.sh"
echo " config lvs on  $LOCAL_HOST $LOCAL_IP "
echo "#! /bin/bash
. /etc/bashrc
. \$APP_BASE/install/funs.sh

CMDTYPE=\"\"
if [ \"\$#\" -gt \"0\" ] ; then
    CMDTYPE=\"\$1\"
fi
echo \" config \$LOCAL_IP iptables port trans \"
install_ha=\`isInstallHaproxy\`
echo \"install_ha=\$install_ha\"
appHosts=\`getAppHosts zookeeper \`
if [ \"\$install_ha\" != \"true\" ] ; then  # 未装ha
echo \"not install haproxy\"
exit 1
fi
"> $netTransFile



VIP=$NEBULA_VIP

##### 安装HA后应该只需要转发到HA上

#  HA KA 同主机 非KA master 需要预处理
#    iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 2182 -j DNAT --to \$LOCAL_IP:2181

######## ipvsadm -lnc
# ipvsadm -L -n
#iptables -t nat -I PREROUTING -p tcp -d 172.16.131.131 --dport 6307 -j DNAT --to :6378
#virtual_server_group www {
#    192.168.0.252 80
#    192.168.0.253 80
#}
# virtual_server group www  # in big lvs cluster
#rr 轮询算法，它将请求依次分配给不同的rs节点，也就是RS节点中均摊分配。这种算法简单，但只适合于RS节点处理性能差不多的情况
#wrr 加权轮训调度，它将依据不同RS的权值分配任务。权值较高的RS将优先获得任务，并且分配到的连接数将比权值低的RS更多。相同权值的RS得到相同数目的连接数。
#Wlc 加权最小连接数调度，假设各台RS的全职依次为Wi，当前tcp连接数依次为Ti，依次去Ti/Wi为最小的RS作为下一个分配的RS
#Dh 目的地址哈希调度（destination hashing）以目的地址为关键字查找一个静态hash表来获得需要的RS
#sh 源地址哈希调度（source hashing）以源地址为关键字查找一个静态hash表来获得需要的RS
#Lc 最小连接数调度（least-connection）,IPVS表存储了所有活动的连接。LB会比较将连接请求发送到当前连接最少的RS.
#lblc 基于地址的最小连接数调度（locality-based least-connection）：将来自同一个目的地址的请求分配给同一台RS，此时这台服务器是尚未满负荷的。否则就将这个请求分配给连接数最小的RS，并以它作为下一次分配的首先考虑。

echo "# config virtual_servers
">$destFile


haHosts=`getAppHosts haproxy `
kaHosts=`getAppHosts keepalived `
echo "#kaHosts=$kaHosts###haHosts=$haHosts###################"

kaIsHa="true"
if [ "${haHosts/$LOCAL_HOST/}" = "${haHosts}" ] ; then # 本机未安装 ha
    kaIsHa="false"
fi

echo "
haHosts=\`getAppHosts haproxy \`
kaHosts=\`getAppHosts keepalived \`
kaIsHa=\"true\"
if [ \"\${haHosts/\$LOCAL_HOST/}\" = \"\${haHosts}\" ] ; then # 本机未安装 ha
    kaIsHa=\"false\"
fi
">> $netTransFile
 
#haproxy  config
if [ "`check_app haproxy`" = "true" ] ; then
echo "
#haproxy config
virtual_server_group haproxy {
    $VIP 88
    $VIP 86
    $VIP 80
#kafka
    $VIP 8092
#ha
    $VIP 48800
}
virtual_server group haproxy {
    delay_loop 3
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 88 {
        weight 100
        MISC_CHECK {
              misc_path \"/usr/bin/ssh $thisNodeIP /usr/bin/systemctl status haproxy \"
              misc_timeout 10
              misc_dynamic
       }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config haproxy pub port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 88 -j DNAT --to \$LOCAL_IP:88
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 86 -j DNAT --to \$LOCAL_IP:86
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 80 -j DNAT --to \$LOCAL_IP:80
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 8092 -j DNAT --to \$LOCAL_IP:8092
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 48800 -j DNAT --to \$LOCAL_IP:48800
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 88 -j DNAT --to \$LOCAL_IP:88
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 86 -j DNAT --to \$LOCAL_IP:86
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 80 -j DNAT --to \$LOCAL_IP:80
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 8092 -j DNAT --to \$LOCAL_IP:8092
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 48800 -j DNAT --to \$LOCAL_IP:48800
   fi
fi
    ">> $netTransFile

fi


################### zk mysql 个性化设置 ###################################

if [ "`check_app zookeeper`" = "true" ] ; then
echo " #zookeeper  config
virtual_server_group zookeeper {
    $VIP 2182
    $VIP 2181
}
virtual_server group zookeeper {
    delay_loop 15
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    alpha
    omega
    quorum 3
    virtualhost \"$LOCAL_HOST\"">>$destFile
#    ha_suspend
#    hysteresis <INT>
#    quorum_up <STRING>|<QUOTED-STRING>
#    quorum_down <STRING>|<QUOTED-STRING>
#    sorry_server <IPADDR> <PORT>
#   persistence_timeout 1
#   persistence_granularity 255.255.255.255

LEN=0
appHosts=`getAppHosts zookeeper  `
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 2181 {
        weight 100
        inhibit_on_failure ">>$destFile
#        notify_up <STRING>|<QUOTED-STRING>
#        notify_down <STRING>|<QUOTED-STRING>
        # HTTP_GET|SSL_GET|TCP_CHECK|SMTP_CHECK|MISC_CHECK

if [ "${appHosts/$NODE01/}" = "$appHosts" ] ; then
    echo "        TCP_CHECK {
            connect_timeout 5
            nb_get_retry 3
            delay_before_retry 3
        } ">>$destFile
else
    echo "         MISC_CHECK {
              misc_path \"/usr/bin/ssh $thisNodeIP /usr/local/bin/zk_status\"
              misc_timeout 10
              misc_dynamic
          }">>$destFile

fi
echo "     }">>$destFile

        #HTTP_GET|SSL_GET {
        #    url {
        #        path /
        #       # digest <STRING> # Digest computed with genhash # genhash -s 192.168.2.188 -p 80 -u /index.html
        #        status_code 200
        #    }
        #
        #    connect_port 49997
        #    connect_timeout 10
        #    nb_get_retry 3
        #    delay_before_retry 3
        #}
       #TCP_CHECK {
       #    connect_timeout 10
       #    nb_get_retry 3
       #    delay_before_retry 3
       #    connect_port 2181
       #}
done
echo "}">>$destFile


    echo "echo 'config zookeeper port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 2182 -j DNAT --to \$LOCAL_IP:2182
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 2181 -j DNAT --to \$LOCAL_IP:2182
if [ \"\$kaIsHa\" = \"true\" ] ; then
        #iptables -t nat -I PREROUTING -p tcp -d \$LOCAL_IP --dport 2182 -j DNAT --to :2181
        #iptables -t nat -A OUTPUT     -p tcp -d 127.0.0.1  --dport 2182 -j DNAT --to 127.0.0.1:2181
        #iptables -t nat -A OUTPUT     -p tcp -d \$LOCAL_IP --dport 2182 -j DNAT --to 127.0.0.1:2181
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\" ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 2182 -j DNAT --to \$LOCAL_IP:2182
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 2181 -j DNAT --to \$LOCAL_IP:2182
    fi
fi
    ">> $netTransFile

fi #end zk

if [ "`check_app mysql`" = "true" ] ; then
echo "
#mysql  config
virtual_server $VIP 3307 {
    delay_loop 15
    lb_algo  wrr
    lb_kind  DR
    protocol TCP
    alpha
    omega
#    persistence_timeout 1
#    persistence_granularity 255.255.255.255
#    quorum 2
#    quorum_up \"\"
#    quorum_down \"$MYSQL_HOME/sbin/stop_mysql_cluster.sh\"
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
appHosts=`getAppHosts mysql  `
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo " real_server $thisNodeIP 3306 {
        weight 100  " >>$destFile
    if [ "${appHosts/$NODE01/}" = "$appHosts" ] ; then
    echo "        TCP_CHECK {
            connect_timeout 5
            nb_get_retry 3
            delay_before_retry 3
        } " >>$destFile
    else
echo "     MISC_CHECK {
              misc_path \"/usr/bin/ssh $thisNodeIP /usr/local/bin/mysql_status\"
              misc_timeout 10
              misc_dynamic
       } " >>$destFile
    fi
echo "}">>$destFile
done
echo "}">>$destFile

echo "echo 'config mysql port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 3307 -j DNAT --to \$LOCAL_IP:3307
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 3306 -j DNAT --to \$LOCAL_IP:3306
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 3307 -j DNAT --to \$LOCAL_IP:3306
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 3306 -j DNAT --to \$LOCAL_IP:3306
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 3307 -j DNAT --to \$LOCAL_IP:3306
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 3306 -j DNAT --to \$LOCAL_IP:3306
    elif [ \"\$CMDTYPE\" = \"start\" ] ; then # master del
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 3307 -j DNAT --to \$LOCAL_IP:3307
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 3306 -j DNAT --to \$LOCAL_IP:3306
    fi
fi
    ">> $netTransFile


echo "
#mysql  config
virtual_server $VIP  3306 {
    delay_loop 15
    lb_algo  sh
    lb_kind  DR
    persistence_timeout 30
    persistence_granularity 255.255.255.255
    protocol TCP
    virtualhost \"$LOCAL_HOST\"">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    thisNodeIP=`getHostIPFromPing $NODE01`
    weight=1
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 3306 {">>$destFile
    if [ "$NODE01" = "$LOCAL_HOST" ] ; then
        echo "        weight 255 ">>$destFile
    else
        ((LEN++))
        if [ "$LEN" -gt "1" ] ; then
             weight=`expr $weight + $weight \* 10`
        fi
        echo "        weight $weight ">>$destFile
    fi

    if [ "${appHosts/$NODE01/}" = "$appHosts" ] ; then
    echo "        TCP_CHECK {
            connect_timeout 5
            nb_get_retry 3
            delay_before_retry 3
        } " >>$destFile
    else
 echo "         MISC_CHECK {
              misc_path \"/usr/bin/ssh $thisNodeIP /usr/local/bin/mysql_status\"
              misc_timeout 10
              misc_dynamic
       }" >>$destFile
    fi
    echo "    }">>$destFile
done
echo "}">>$destFile

fi


#mongo  config
if [ "`check_app mongo`" = "true" ] ; then
echo "
virtual_server_group mongo {
    $VIP 27017
    $VIP 27019
}
#mongo  config
virtual_server group mongo {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 27017 {
        weight 100
        TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile

echo "echo 'config mongo port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 27019 -j DNAT --to \$LOCAL_IP:27019
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 27017 -j DNAT --to \$LOCAL_IP:27019
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 27019 -j DNAT --to \$LOCAL_IP:27017
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 27017 -j DNAT --to \$LOCAL_IP:27017
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 27019 -j DNAT --to \$LOCAL_IP:27017
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 27017 -j DNAT --to \$LOCAL_IP:27017
    elif [ \"\$CMDTYPE\" = \"start\" ] ; then # master del
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 27019 -j DNAT --to \$LOCAL_IP:27019
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 27017 -j DNAT --to \$LOCAL_IP:27019
    fi
fi
    ">> $netTransFile

fi

#codis  config
if [ "`check_app codis`" = "true" ] ; then
echo "#codis  config
virtual_server_group codis {
    $VIP 6307
    $VIP 6377
}
virtual_server $VIP codis {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 6377 {
        weight 100
        TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config codis port '
    iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 6307 -j DNAT --to \$LOCAL_IP:6307
    iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 6377 -j DNAT --to \$LOCAL_IP:6307
    iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 6307 -j DNAT --to \$LOCAL_IP:6377
    iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 6377 -j DNAT --to \$LOCAL_IP:6377
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 6307 -j DNAT --to \$LOCAL_IP:6377
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 6377 -j DNAT --to \$LOCAL_IP:6377
    elif [ \"\$CMDTYPE\" = \"start\" ] ; then # master del
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 6307 -j DNAT --to \$LOCAL_IP:6307
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 6377 -j DNAT --to \$LOCAL_IP:6307
    fi
fi
    ">> $netTransFile

fi


#eagles config
if [ "`check_app eagles`" = "true" ] ; then
echo "
virtual_server_group eagles {
    $VIP 17100
    $VIP 9121
}
#eagles config
virtual_server group eagles {
    delay_loop 3
    lb_algo  sh
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 17100 {
        weight 100
        HTTP_GET {
            url {
                path /cluster/health
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile

echo "echo 'config eagles port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9121 -j DNAT --to \$LOCAL_IP:9121
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 17100 -j DNAT --to \$LOCAL_IP:9121
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9121 -j DNAT --to \$LOCAL_IP:17100
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 17100 -j DNAT --to \$LOCAL_IP:17100
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9121 -j DNAT --to \$LOCAL_IP:17100
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 17100 -j DNAT --to \$LOCAL_IP:17100
    elif [ \"\$CMDTYPE\" = \"start\" ] ; then # master del
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9121 -j DNAT --to \$LOCAL_IP:9121
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 17100 -j DNAT --to \$LOCAL_IP:9121
    fi
fi
    ">> $netTransFile

fi

#nump  config
if [ "`check_app nump`" = "true" ] ; then
echo "
virtual_server_group nump {
    $VIP 10056
    $VIP 10057
}
#nump config
virtual_server group nump {
    delay_loop 3
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 10057 {
        weight 100
        HTTP_GET {
            url {
                path /nump/
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile

echo "echo 'config nump port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10056 -j DNAT --to \$LOCAL_IP:10056
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10057 -j DNAT --to \$LOCAL_IP:10056
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10056 -j DNAT --to \$LOCAL_IP:10056
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10057 -j DNAT --to \$LOCAL_IP:10056
    fi
fi
    ">> $netTransFile


fi


#cayman  config
if [ "`check_app cayman`" = "true" ] ; then
echo "
#cayman config
virtual_server $VIP 9131 {
    delay_loop 3
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 80 {
        weight 100
        HTTP_GET {
            url {
                path /api/cayman/store/stat/global/get?debug=true
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config cayman port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9131 -j DNAT --to \$LOCAL_IP:9131
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o \"\$CMDTYPE\" = \"start\"    ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9131 -j DNAT --to \$LOCAL_IP:9131
    fi
fi
    ">> $netTransFile

fi




if [ "`check_app hivecore`" = "true" ] ; then
echo "
#hivecore  config
virtual_server $VIP 8060 {
    delay_loop 5
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 8060 {
        weight 100
       HTTP_GET {
            url {
                path /sobeyhive-fp/
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile

echo "echo 'config hivecore port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 8060 -j DNAT --to \$LOCAL_IP:8060
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 8060 -j DNAT --to \$LOCAL_IP:8060
    fi
fi
    ">> $netTransFile

fi

if [ "`check_app ftengine2`" = "true" ] ; then
echo "
#ftengine2  config
virtual_server $VIP 8090 {
    delay_loop 5
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 8090 {
        weight 100
       HTTP_GET {
            url {
                path /ftengine/
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config ftengine2 port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 8090 -j DNAT --to \$LOCAL_IP:8090
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 8090 -j DNAT --to \$LOCAL_IP:8090
    fi
fi
    ">> $netTransFile
fi




#nebula  config
if [ "`check_app nebula`" = "true" ] ; then
echo "
#nebula  config
virtual_server $VIP 9090 {
    delay_loop 5
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9090 {
        weight 100
       HTTP_GET {
            url {
                path  /api/version
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config nebula port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9090 -j DNAT --to \$LOCAL_IP:9090
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9090 -j DNAT --to \$LOCAL_IP:9090
    fi
fi
    ">> $netTransFile

fi

#nebula  config
if [ "`check_app ntag`" = "true" ] ; then
echo "
#nebula  config
virtual_server $VIP 9060 {
    delay_loop 5
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9060 {
        weight 100
       HTTP_GET {
            url {
                path  /user/#/login
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config ntag port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9060 -j DNAT --to \$LOCAL_IP:9060
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9060 -j DNAT --to \$LOCAL_IP:9060
    fi
fi
    ">> $netTransFile

fi


#infoshare  config
if [ "`check_app infoshare`" = "true" ] ; then
echo "#cmserver  config
virtual_server_group infoshare {
    $VIP 9080
    $VIP 82
}
virtual_server group infoshare {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9080 {
        weight 100
       HTTP_GET {
            url {
                path  /news/login.jsp
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
 echo "}">>$destFile

echo "echo 'config cmserver port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9080 -j DNAT --to \$LOCAL_IP:82
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 82   -j DNAT --to \$LOCAL_IP:82
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o \"\$CMDTYPE\" = \"start\" ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 82   -j DNAT --to \$LOCAL_IP:82
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9080 -j DNAT --to \$LOCAL_IP:82
    fi
fi
    ">> $netTransFile

fi

#cmserver  config
if [ "`check_app cmserver`" = "true" ] ; then
echo "#cmserver  config
virtual_server_group cmserver {
    $VIP 9023
    $VIP 9022
}
virtual_server group cmserver {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9022 {
        weight 100
       HTTP_GET {
            url {
                path  /CMApi/api/basic/account/testconnect
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
 echo "}">>$destFile

echo "echo 'config cmserver port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9023 -j DNAT --to \$LOCAL_IP:9023
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9022 -j DNAT --to \$LOCAL_IP:9023
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o \"\$CMDTYPE\" = \"start\" ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9023 -j DNAT --to \$LOCAL_IP:9023
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9022 -j DNAT --to \$LOCAL_IP:9023
    fi
fi
    ">> $netTransFile


echo "#cmserver windows  config
virtual_server_group cmswin {
    $VIP 9037
    $VIP 9036
}
virtual_server group cmswin {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    persistence_timeout 10
    persistence_granularity 255.255.255.255
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9036 {
        weight 100
       HTTP_GET {
            url {
                path  /CMApi/api/basic/account/testconnect
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
 echo "}">>$destFile
echo "echo 'config cmswin port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9037 -j DNAT --to \$LOCAL_IP:9037
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9036 -j DNAT --to \$LOCAL_IP:9037
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9037 -j DNAT --to \$LOCAL_IP:9037
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9036 -j DNAT --to \$LOCAL_IP:9037
    fi
fi
    ">> $netTransFile

fi




#cmweb  config
if [ "`check_app cmweb`" = "true"  "`check_app cmserver `" = "true"  ] ; then
echo "#cmweb config
virtual_server_group cmweb {
    $VIP 9021
    $VIP 9020
}
virtual_server group cmweb {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9020 {
        weight 100
       HTTP_GET {
            url {
                path  /index.aspx
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config cmweb port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9021 -j DNAT --to \$LOCAL_IP:9021
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9020 -j DNAT --to \$LOCAL_IP:9021
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9021 -j DNAT --to \$LOCAL_IP:9021
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9020 -j DNAT --to \$LOCAL_IP:9021
    fi
fi
    ">> $netTransFile

fi


#Streams  config
if [ "`check_app nebula`" = "true" ] ; then
echo "#Streams_Bucket config
virtual_server $VIP 9010 {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9010 {
        weight 100
       HTTP_GET {
            url {
                path /hacheck/index.html
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
 echo "}">>$destFile
echo "echo 'config stream port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9010 -j DNAT --to \$LOCAL_IP:9010
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9010 -j DNAT --to \$LOCAL_IP:9010
    fi
fi
    ">> $netTransFile
fi

#ingestdbsvr  config
if [ "`check_app ingestdbsvr`" = "true" ] ; then
echo "#ingestdbsvr config
virtual_server_group ingestdbsvr {
    $VIP 9024
    $VIP 9025
}
virtual_server group ingestdbsvr {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9024 {
        weight 100
       HTTP_GET {
            url {
                path /api/device/GetAllCaptureChannels
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile

echo "echo 'config ingestdbsvr port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9025 -j DNAT --to \$LOCAL_IP:9025
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9024 -j DNAT --to \$LOCAL_IP:9025
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9025 -j DNAT --to \$LOCAL_IP:9025
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9024 -j DNAT --to \$LOCAL_IP:9025
    fi
fi
    ">> $netTransFile


echo "#IngestDEVCTL config
virtual_server_group IngestDEVCTL {
    $VIP 9039
    $VIP 9038
}
virtual_server group IngestDEVCTL {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9038 {
        weight 100
       HTTP_GET {
            url {
                path /api/G2MatrixWebCtrl/getall
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config ingestdbsvr port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9039 -j DNAT --to \$LOCAL_IP:9039
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9038 -j DNAT --to \$LOCAL_IP:9039
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9039 -j DNAT --to \$LOCAL_IP:9039
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9038 -j DNAT --to \$LOCAL_IP:9039
    fi
fi
    ">> $netTransFile

fi



#ingesttasksvr  config
if [ "`check_app ingesttasksvr`" = "true" ] ; then

echo "#ingesttasksvr config
virtual_server_group IngestTaskSvr {
    $VIP 9041
    $VIP 9040
}
virtual_server group IngestTaskSvr {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9040 {
        weight 100
       HTTP_GET {
            url {
                path /sobey/plat/cmd
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config IngestTaskSvr port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9041 -j DNAT --to \$LOCAL_IP:9041
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9040 -j DNAT --to \$LOCAL_IP:9041
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9041 -j DNAT --to \$LOCAL_IP:9041
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9040 -j DNAT --to \$LOCAL_IP:9041
    fi
fi
    ">> $netTransFile

fi




#ingestmsgsvr  config
if [ "`check_app ingestmsgsvr`" = "true" ] ; then
echo "#ingesttasksvr config
virtual_server_group ingestmsgsvr {
    $VIP 9043
    $VIP 9042
}
virtual_server group ingestmsgsvr {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9042 {
        weight 100
       HTTP_GET {
            url {
                path /Plat.Web/NormalServicePage.html
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config ingestmsgsvr port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9043 -j DNAT --to \$LOCAL_IP:9043
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9042 -j DNAT --to \$LOCAL_IP:9043
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9043 -j DNAT --to \$LOCAL_IP:9043
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9042 -j DNAT --to \$LOCAL_IP:9043
    fi
fi
    ">> $netTransFile

fi


#mosgateway  config
if [ "`check_app mosgateway`" = "true" ] ; then
echo "#ingesttasksvr config
virtual_server_group MosGateway10540 {
    $VIP 10540
    $VIP 10550
}
virtual_server group MosGateway10540 {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 10550 {
        weight 100
       TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config MosGateway10540 port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10540 -j DNAT --to \$LOCAL_IP:10540
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10550 -j DNAT --to \$LOCAL_IP:10540
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10540 -j DNAT --to \$LOCAL_IP:10540
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10550 -j DNAT --to \$LOCAL_IP:10540
    fi
fi
    ">> $netTransFile

echo "
virtual_server_group MosGateway10541 {
    $VIP 10541
    $VIP 10551
}
virtual_server group MosGateway10541 {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 10551 {
        weight 100
       TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config MosGateway10541 port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10541 -j DNAT --to \$LOCAL_IP:10541
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10551 -j DNAT --to \$LOCAL_IP:10541
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10541 -j DNAT --to \$LOCAL_IP:10541
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10551 -j DNAT --to \$LOCAL_IP:10541
    fi
fi
    ">> $netTransFile

echo "
virtual_server_group MosGateway10542 {
    $VIP 10542
    $VIP 10552
}
virtual_server group MosGateway10542 {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 10552 {
        weight 100
       TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config MosGateway10542 port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10542 -j DNAT --to \$LOCAL_IP:10542
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10552 -j DNAT --to \$LOCAL_IP:10542
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10542 -j DNAT --to \$LOCAL_IP:10542
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10552 -j DNAT --to \$LOCAL_IP:10542
    fi
fi
    ">> $netTransFile

echo "
virtual_server_group MosGateway10555 {
    $VIP 10555
    $VIP 10556
}
virtual_server group MosGateway10555 {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 10556 {
        weight 100
       TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config MosGateway10555 port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10555 -j DNAT --to \$LOCAL_IP:10555
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 10556 -j DNAT --to \$LOCAL_IP:10555
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10555 -j DNAT --to \$LOCAL_IP:10555
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 10556 -j DNAT --to \$LOCAL_IP:10555
    fi
fi
    ">> $netTransFile
fi



#jove  config
if [ "`check_app jove`" = "true" ] ; then
echo "
virtual_server_group jove {
    $VIP 9027
    $VIP 9026
}
virtual_server group jove {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9026 {
        weight 100
        HTTP_GET {
            url {
                path /Cm/Login?usertoken=
                status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config jove port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9027 -j DNAT --to \$LOCAL_IP:9027
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9026 -j DNAT --to \$LOCAL_IP:9027
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9027 -j DNAT --to \$LOCAL_IP:9027
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9026 -j DNAT --to \$LOCAL_IP:9027
    fi
fi
    ">> $netTransFile
fi

#otcserver  config
if [ "`check_app otcserver`" = "true" ] ; then
echo "
virtual_server_group otcserver {
    $VIP 9045
    $VIP 9044
}
virtual_server group otcserver {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9044 {
        weight 100
        HTTP_GET {
            url {
                path /getotc
#    option    httpchk GET /getotc HTTP/1.1\r\nHost:\ www
               status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config otcserver port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9045 -j DNAT --to \$LOCAL_IP:9045
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9044 -j DNAT --to \$LOCAL_IP:9045
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9045 -j DNAT --to \$LOCAL_IP:9045
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9044 -j DNAT --to \$LOCAL_IP:9045
    fi
fi
    ">> $netTransFile
fi



#Floating license Server  config
if [ "`check_app floatinglicenseserver`" = "true" ] ; then
echo "
virtual_server_group floatinglicenseserver {
    $VIP 9033
    $VIP 9032
}
virtual_server group floatinglicenseserver {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9032 {
        weight 100
        HTTP_GET {
            url {
                path /testalive
               status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config floatinglicenseserver port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9033 -j DNAT --to \$LOCAL_IP:9033
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9032 -j DNAT --to \$LOCAL_IP:9033
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9033 -j DNAT --to \$LOCAL_IP:9033
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9032 -j DNAT --to \$LOCAL_IP:9033
    fi
fi
    ">> $netTransFile

echo "
virtual_server_group FLSvr9031 {
    $VIP 9031
    $VIP 9030
}
virtual_server group FLSvr9031 {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9030 {
        weight 100
        TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config FLSvr9031 port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9031 -j DNAT --to \$LOCAL_IP:9031
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9030 -j DNAT --to \$LOCAL_IP:9031
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9031 -j DNAT --to \$LOCAL_IP:9031
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9030 -j DNAT --to \$LOCAL_IP:9031
    fi
fi
    ">> $netTransFile

echo "
virtual_server_group FLSvr9035 {
    $VIP 9035
    $VIP 9034
}
virtual_server group FLSvr9035 {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9034 {
        weight 100
        HTTP_GET {
            url {
                path /api/Studio/heartbeat
               status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config FLSvr9035 port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9035 -j DNAT --to \$LOCAL_IP:9035
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9034 -j DNAT --to \$LOCAL_IP:9035
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9035 -j DNAT --to \$LOCAL_IP:9035
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9034 -j DNAT --to \$LOCAL_IP:9035
    fi
fi
    ">> $netTransFile

fi
#sangha tcp  config
if [ "`check_app sangha`" = "true" ] ; then
echo "
virtual_server_group sangha {
    $VIP 4505
    $VIP 4504
}
virtual_server group sangha {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 4504 {
        weight 100
        TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config sangha port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 4505 -j DNAT --to \$LOCAL_IP:4505
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 4504 -j DNAT --to \$LOCAL_IP:4505
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 4505 -j DNAT --to \$LOCAL_IP:4505
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 4504 -j DNAT --to \$LOCAL_IP:4505
    fi
fi
    ">> $netTransFile

echo "
virtual_server_group sanghaserver {
    $VIP 9047
    $VIP 9046
}
virtual_server group sanghaserver {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9046 {
        weight 100
        HTTP_GET {
            url {
                path /sobey/plat/cmd
               status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config sanghaserver port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9047 -j DNAT --to \$LOCAL_IP:9047
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9046 -j DNAT --to \$LOCAL_IP:9047
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9047 -j DNAT --to \$LOCAL_IP:9047
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9046 -j DNAT --to \$LOCAL_IP:9047
    fi
fi
    ">> $netTransFile

echo "
virtual_server_group sanghaweb {
    $VIP 9049
    $VIP 9048
}
virtual_server group sanghaweb {
    delay_loop 10
    lb_algo  rr
    lb_kind  DR
    protocol TCP
    virtualhost \"$LOCAL_HOST\" ">>$destFile
LEN=0
for NODE01 in $haHosts ; do
    ((LEN++))
    thisNodeIP=`getHostIPFromPing $NODE01`
    if [ "$thisNodeIP" = "" ] ; then
        continue
    fi
    echo "    real_server $thisNodeIP 9048 {
        weight 100
        HTTP_GET {
            url {
                path /Plat.Web/NormalServicePage.html
               status_code 200
            }
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
        }
    }">>$destFile
done
echo "}">>$destFile
echo "echo 'config sanghaweb port '
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9049 -j DNAT --to \$LOCAL_IP:9049
iptables -t nat -D PREROUTING -p tcp -d \$NEBULA_VIP --dport 9048 -j DNAT --to \$LOCAL_IP:9049
if [ \"\$kaIsHa\" = \"true\" ] ; then
    if [  \"\$CMDTYPE\" = \"stop\" -o  \"\$CMDTYPE\" = \"start\"  ] ; then  # 非master add
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9049 -j DNAT --to \$LOCAL_IP:9049
        iptables -t nat -I PREROUTING -p tcp -d \$NEBULA_VIP --dport 9048 -j DNAT --to \$LOCAL_IP:9049
    fi
fi
    ">> $netTransFile

fi

#################### 请在些之前添加LVS服务###############################################################################################################################################
chmod +x $netTransFile
#for HOST in ${CLUSTER_HOST_LIST//,/ } ; do
#    if [ "${kaHosts/$HOST/}" = "${kaHosts}" ] ; then
#       echo  "scp $netTransFile $HOST:$netTransFile"
#       scp $netTransFile $HOST:$netTransFile
#    fi
#done
echo "lvs config in: $destFile"
echo "rs port trans in : $netTransFile"

exit 0
