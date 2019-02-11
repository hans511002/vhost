#! /bin/bash

# Program:
#	Install Keepalived :
BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ "$#" -lt "2" ] ; then
    echo "usetag: LOCAL_IP LOCAL_HOST"
    exit 1
fi
 
LOCAL_IP=$1
LOCAL_HOST=$2
KA_HOME=$BIN

#yum install
packages="keepalived ipvsadm net-snmp"
yum install -y $packages
if [ $? -ne 0 ];then
    error_package=`yum install -y $packages 2>&1 | grep "Error: Package:"`
    rpmdb_problem=`yum install -y $packages 2>&1 | grep "rpmdb problem"`
    if [ -n "$error_package" ];then
        error_package=`yum install -y $packages 2>&1 | grep "Installed:" | awk -F '(' '{print $1}' | awk -F 'Installed: ' '{print $NF}'`
        yum remove -y $error_package
    fi
    
    if [ -n "$rpmdb_problem" ];then
        rpmdb_problem=`yum install -y $packages 2>&1 | grep "has missing requires of" | awk -F 'has missing requires of ' '{print $NF}' | awk -F '[>=(]' '{print $1}'`
        if [ -n "$rpmdb_problem" ];then
            yum install -y $rpmdb_problem
        fi
        
        rpmdb_problem=`yum install -y $packages 2>&1 | grep "is a duplicate with" | grep -v "yum" | awk -F 'is a duplicate with ' '{print $NF}' | awk '{print $1}'`
        if [ -n "$rpmdb_problem" ];then
            yum remove -y $rpmdb_problem
        fi
    fi
    
    yum install -y $packages
    if [ $? -ne 0 ];then
        echo "exec failed: yum install -y $packages"
        exit 1
    fi
fi

. $APP_BASE/install/funs.sh


installLvs=$(cat $KA_HOME/keepalived_install.conf | grep "host.install.lvs" | awk -F '=' '{print $2}')
if [ "$installLvs" != "true" ] ; then
    installLvs="false"
fi

export INSTALL_LVS="$installLvs"
for HOST in ${CLUSTER_HOST_LIST//,/ } ; do
    ssh $HOST "sed -i -e 's|export INSTALL_LVS=.*|export INSTALL_LVS=\"$installLvs\"|'  /etc/profile.d/1sobeyhive.sh"
done

#
echo "start config keepalived $LOCAL_IP"
LocalIP2Priority=$LOCAL_IP
if [ -f "$KA_HOME/keepalived_install.conf" ] ; then
PRIORITY=$(cat $KA_HOME/keepalived_install.conf | grep "PRIORITY.$LocalIP2Priority" | awk -F '=' '{print $2}')
fi
if [ "$PRIORITY" = "" ] ; then
    PRIORITY=100
    for host in `cat $KA_HOME/conf/servers` ; do
        ((PRIORITY++))
        if [ "$host" = "$HOSTNAME" ] ; then
            break
        fi
    done
fi

if [ -f "$KA_HOME/keepalived_install.conf" ] ; then
SERVICE_ENABLE=$(cat $KA_HOME/keepalived_install.conf | grep 'SERVICE_ENABLE=' | awk -F '=' '{print $2}')
else
SERVICE_ENABLE="false"
fi
LocalIP=$LocalIP2Priority
# 获取拥有当前IP的网卡
IP2Interface=$(ifconfig | grep -B 3 "$LocalIP" | grep 'BROADCAST' | cut -d: -f1)
if [ "$IP2Interface" = "" ] ; then
    IP2Interface=`ip a|grep "$LocalIP"|awk '{print $7}'`
    if [ "$IP2Interface" = "" ] ; then
       IP2Interface="eno0"
    fi
fi

echo "IP2Interface=$IP2Interface"

if [ "$NEBULA_VIP" = "" ] ; then
    echo "NEBULA_VIP is not set"
    exit 1
fi

VIP_ID=$(echo "$NEBULA_VIP" | awk -F. '{print $4}')
VIP_NAME="VI_$VIP_ID"

mkdir -p /etc/keepalived
KA_HEADERFILE="/etc/keepalived/header.conf"
KA_LVSFILE="/etc/keepalived/lvs.conf"


echo "! Configuration File for keepalived

global_defs {
#    notification_email {
#        a@abc.com
#        b@abc.com
#        ...
#    }
#    notification_email_from alert@abc.com
#    smtp_server smtp.abc.com
#    smtp_connect_timeout 30
#    enable_traps
   router_id $LOCAL_HOST
}

vrrp_script chk_haproxy {
    script \"$KA_HOME/scripts/ka_check.sh\"
    interval 2
    weight -10
}

vrrp_instance $VIP_NAME {
    state backup
    interface $IP2Interface
    dont_track_primary
    track_interface {
        $IP2Interface
    }
    virtual_router_id $VIP_ID
    garp_master_delay 3
    priority $PRIORITY
    nopreempt
    preempt_delay 5
    mcast_src_ip $LocalIP
    advert_int 1
#单播
#    unicast_src_ip  $LOCAL_IP
#    unicast_peer { 
#                 IP # 其它目的IP
#                } 
    authentication {
        auth_type PASS
        auth_pass 1111
    }
     track_script {
        chk_haproxy
     }
    virtual_ipaddress {
        $NEBULA_VIP dev $IP2Interface scope globa
  # muli interface vip
    }
   notify_master  $KA_HOME/scripts/ka_master.sh
   notify_backup  $KA_HOME/scripts/ka_backup.sh
   notify_fault   $KA_HOME/scripts/ka_fault.sh
   #notify <STRING>|<QUOTED-STRING>
   #smtp_alert
}

">$KA_HEADERFILE

## keepalived iptables 配置
#/sbin/iptables -A INPUT -i eth1 -d 224.0.0.0/8 -j ACCEPT 
#/sbin/iptables -A INPUT -i eth1 -p 112 -j ACCEPT 
# keepalived 多播包
#tcpdump -v -i eth0 host 224.0.0.18 
#tcpdump -vvv -n -i eth1 host 224.0.0.18


# 配置日志
sed  -i "s#KEEPALIVED_OPTIONS=.*#KEEPALIVED_OPTIONS=\" -D -d -S 1\"#g" /etc/sysconfig/keepalived
mkdir -p ${LOGS_BASE}/keepalived
echo "
#keepalived -S 1
local1.*   ${LOGS_BASE}/keepalived/keepalived.log 
" > /etc/rsyslog.d/keepalived_log.conf 

#logrotate
echo "$LOGS_BASE/keepalived/keepalived.log {
    su root
    daily
    rotate 30
    missingok
    notifempty
    compress
    dateext
    sharedscripts
    postrotate
        /bin/kill -HUP \`cat /var/run/syslogd.pid 2> /dev/null\` 2> /dev/null || true
        /bin/kill -HUP \`cat /var/run/rsyslogd.pid 2> /dev/null\` 2> /dev/null || true
    endscript
}" > /etc/logrotate.d/keepalived

systemctl restart rsyslog 
systemctl stop keepalived

echo " config keepalived service "
echo "[Unit]
Description=LVS and VRRP High Availability Monitor
After=syslog.target network-online.target

[Service]
Type=forking
PIDFile=/var/run/keepalived.pid
KillMode=process
EnvironmentFile=-/etc/sysconfig/keepalived
ExecStart=/sobeyhive/app/keepalived-1.2.13/sbin/keepalived_server.sh start \$KEEPALIVED_OPTIONS
ExecReload=/sobeyhive/app/keepalived-1.2.13/sbin/keepalived_server.sh restart \$MAINPID
ExecStop=/sobeyhive/app/keepalived-1.2.13/sbin/keepalived_server.sh stop  -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
" > /usr/lib/systemd/system/keepalived.service
systemctl daemon-reload

## ExecReload=/bin/kill -HUP $MAINPID
#sed -i -e "s|ExecReload=.*||" /usr/lib/systemd/system/keepalived.service
#sed -i -e "s|ExecStart=.*|ExecStart=$KA_HOME/sbin/keepalived_server.sh start \$KEEPALIVED_OPTIONS|" /usr/lib/systemd/system/keepalived.service
#stopShel=`cat /usr/lib/systemd/system/keepalived.service |grep "ExecReload="`
#if [ "$stopShel" = "" ] ; then
#   sed -i "/ExecStart=.*/a\\ExecReload=$KA_HOME/sbin/keepalived_server.sh restart \$MAINPID"  /usr/lib/systemd/system/keepalived.service 
#else
#    sed -i -e "s|ExecReload=/bin/kill.*|ExecReload=$KA_HOME/sbin/keepalived_server.sh restart  -HUP \$MAINPID|" /usr/lib/systemd/system/keepalived.service
#fi
#stopShel=`cat /usr/lib/systemd/system/keepalived.service |grep "ExecStop="`
#if [ "$stopShel" = "" ] ; then
#   sed -i "/ExecReload=.*/a\\ExecStop=$KA_HOME/sbin/keepalived_server.sh stop \$MAINPID"  /usr/lib/systemd/system/keepalived.service 
#else
#    sed -i -e "s|ExecStop=.*|ExecStop=$KA_HOME/sbin/keepalived_server.sh stop  -HUP \$MAINPID|" /usr/lib/systemd/system/keepalived.service
#fi

echo ""> /etc/keepalived/lvs.conf
echo ""> $APP_BASE/install/iptable_trans.sh
install_ha=`isInstallHaproxy`
if [ "$INSTALL_LVS" = "true" -a "$install_ha" = "true" ] ; then
    echo "config to open lvs :  begin to config LVS.........."
     if [ -f "$APP_BASE/install/keepalived/keepalived_lvs.sh" ] ; then
        $APP_BASE/install/keepalived/lvs_config.sh $LOCAL_IP $LOCAL_HOST 
        if [ "$?" != "0" ] ; then
            echo "config lvs failed"
            exit 1
        fi
     fi
     echo "end config LVS "
fi

systemctl daemon-reload
systemctl start keepalived 

if [ "$SERVICE_ENABLE" = "true" ] ; then
 	systemctl enable keepalived 	   
 	chkconfig keepalived on	   
fi

exit 0
