#!/bin/bash

BIN=$(cd $(dirname $0); pwd)
cd $BIN
if [ "$#" -lt "2" ] ; then
    echo "not in installer exec"
fi

yum install -y yum-utils 
yum-config-manager --add-repo https://download.docker.com/linux/centos/7/x86_64/stable


chmod u+s /bin/ping

sed -i -e 's/SELINUX=enforcing/#SELINUX=enforcing/' /etc/selinux/config
echo "SELINUX=disabled">> /etc/selinux/config
setenforce 0

#force set timezone
rm -rf  /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

sed -i -e 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
sed -i -e 's/UseDNS .*/UseDNS no/' /etc/ssh/sshd_config
service sshd restart

LOCAL_IP=$1
LOCAL_HOST=$2

sed -i -e "s|hive_sysctl|sysctl|g" -e "s|1sobeyhive.sh|1appenv.sh|g" /etc/init.d/shostname.sh
mv /etc/init.d/sobeyhive.sh /etc/init.d/appservice.sh 
sed -i -e "s|hive_sysctl|sysctl|g"  -e "s|sobeyhive.init|app_init.sh|g" -e "s|1sobeyhive.sh|1appenv.sh|g"  /etc/init.d/appservice.sh


. $BIN/1appenv.sh $LOCAL_IP $LOCAL_HOST
#sed  -i  -e ':label; /if.*docker_res.sh/,/fi/ { /fi/! { $! { N; b label }; }; s/if.*docker_res.sh.*fi//; }' /etc/bashrc #需要多行替换
if [ "$?" != "0" ] ; then
    echo "config env error"
    exit 1
fi
echo "export install env: /etc/profile.d/1appenv.sh"
cat /etc/profile.d/1appenv.sh

. /etc/bashrc
. /etc/profile.d/1appenv.sh
if [ "$?" != "0" ] ; then
    echo "load env error: /etc/profile.d/1appenv.sh"
    exit 1
fi
. $APP_BASE/install/funs.sh
$APP_BASE/install/host_firewalld.sh
if [ "$?" != "0" ] ; then
    echo "config firewalld error"
    exit 1
fi

rm -rf $APP_BASE/install/docker_containers

echo "/bin/systemctl stop doceker">/etc/rc.d/rc3.d/K01docker_stop

if [ -f "$BIN/ipconf.xml" ] ; then
    cp -u "$BIN/ipconf.xml" ${APP_BASE}/ipconf.xml
fi
if [ -f "$BIN/publicsetting.xml" ] ; then
    cp -u "$BIN/publicsetting.xml" ${APP_BASE}/publicsetting.xml
fi

mv -f $APP_BASE/install/modify_docker_disk.sh /bin/
if [ -e "$APP_BASE/install/jq"  ] ; then
    mv -f $APP_BASE/install/jq /usr/bin/
fi

if [ -e "$APP_BASE/install/init_base_services.sh"  ] ; then
    $APP_BASE/install/init_base_services.sh
fi
#system started
rm -rf /etc/rc.local
ln -s /etc/rc.d/rc.local /etc/rc.local
chmod +x /etc/rc.d/rc.local

#sed -i -e 's#.*mount /dev/vg-lv.*##' /etc/rc.d/rc.local
#sed -i '/touch.*/a\mount /dev/vg-lv /app ' /etc/rc.d/rc.local

sed -i /^$/d /etc/rc.d/rc.local
sed -i /^[[:space:]]*$/d /etc/rc.d/rc.local

#sys config
$APP_BASE/install/app_sysctl.sh

#yum install
packages="mtr tcpdump sysstat openssl curl nmap nc bc wget socat lsof lsscsi iotop crash net-tools psmisc iproute traceroute mariadb dstat libpcap-devel libpcap ncurses-devel ncurses ncurses-libs yum-utils bridge-utils cifs-utils nfs-utils dos2unix tree telnet"
yum install -y $packages
res=$?
tryTimes=0
while [ $res -ne 0 ]; do
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
    ((tryTimes++))
    yum install -y $packages
    res=$?
    if [ $res -ne 0 -a "$tryTimes" -gt "3" ];then
        echo "exec failed: yum install -y $packages"
        exit 1
    fi
done

###########parse app hosts rel##################################
if [ -f "${APP_BASE}/install/cluster.cfg" ] ; then
    echo "# all app hosts ">/etc/profile.d/app_hosts.sh
    echo "#ALL_APP=$ALL_APP ">>/etc/profile.d/app_hosts.sh
    allApps=${ALL_APP//,/ }
    for appName in $allApps ; do
        hosts=`cat ${APP_BASE}/install/cluster.cfg|grep "app.$appName.install.hosts=" |awk -F= '{print $2}'`
        if [ "$hosts" != "" ] ; then
            echo "export ${appName}_hosts=\"$hosts\" ">>/etc/profile.d/app_hosts.sh
        else
            hosts=`cat ${APP_BASE}/install/cluster.cfg|grep "cluster.$appName.install.hosts=" |awk -F= '{print $2}'`
            if [ "$hosts" != "" ] ; then
                echo "export ${appName}_hosts=\"$hosts\"">>/etc/profile.d/app_hosts.sh
            fi
        fi
    done
    #cp.sh scp $HOSTNAME:/etc/profile.d/app_hosts.sh /etc/profile.d/
    . /etc/profile.d/app_hosts.sh
fi

#config xinetd
echo "config xinet services......"
$BIN/xinet/xinet_config.sh

#upgrade ntp
if [ -f "$APP_BASE/install/ntp/install_ntp.sh" ] ; then
    scp /etc/ntp.conf /etc/ntp.conf.init.bak
    $APP_BASE/install/ntp/install_ntp.sh
fi

if [ -f "$APP_BASE/install/openssh/install_openssh.sh" ] ; then
    $APP_BASE/install/openssh/install_openssh.sh
fi
#if [ -f "$APP_BASE/install/openssh/upgrade_openssh.sh" ] ; then
#    $APP_BASE/install/openssh/upgrade_openssh.sh
#fi

if [ -f "$APP_BASE/install/openssl/install_openssl.sh" ] ; then
    $APP_BASE/install/openssl/install_openssl.sh
fi

echo "INSTALL_DNS=$INSTALL_DNS"
if [ "$INSTALL_DNS" = "true" ] ; then
    echo "config domain .....$PRODUCT_DOMAIN............."
    service appdns stop 2>/dev/null
    # proDomain=$(echo "$PRODUCT_DOMAIN" | awk -F. '{print $1}')
    # rootDomain=${PRODUCT_DOMAIN/$proDomain./}
    # echo "rootDomain=$rootDomain"
    # 不用修改和注释，DNS的相关脚本 已经使用上面的变量INSTALL_DNS控制了
    clusIpLists=`getDnsIpList`
    clusHostLists=`getDnsHostList`
    if [ "$clusHostLists" = "" ] ; then
        echo "config install dns ,but not dns host to install:=clusHostLists=$clusHostLists "
        exit 1
    fi
    echo "export dns_hosts=\"$clusHostLists\"
export dns_ips=\"$clusIpLists\"
" > /etc/profile.d/dns.sh
    
    scp -p /etc/resolv.conf /etc/resolv.conf.bak
    rm -rf /etc/resolv_app.conf
    if [ "${clusHostLists/$LOCAL_HOST/}" != "$clusHostLists" ] ; then
        echo "======================================================================
        $BIN/dns_config.sh \"$clusIpLists\" \"$clusHostLists\" \"$PRODUCT_DOMAIN\" 
         =========================================================================="
        $BIN/dns_config.sh "$clusIpLists" "$clusHostLists" "$PRODUCT_DOMAIN" 
        if [ $? -ne 0 ];then
            echo "dns config failed "
            exit 1
        fi
    else
        OLD_DNS=`cat /etc/resolv.conf|grep "^nameserver"|uniq`
        echo ";generated by deploy ">/etc/resolv.conf
        if [ "$NEBULA_VIP" = "$PRODUCT_DOMAIN" -o "`check_app keepalived`" = "false" ] ; then
            for nip in ${clusIpLists//,/ } ; do
                echo "nameserver $nip" >>/etc/resolv.conf
            done
        else
            echo "nameserver $NEBULA_VIP" >>/etc/resolv.conf
        fi

        for nip in ${clusIpLists//,/ } ; do
           OLD_DNS=`echo "$OLD_DNS" |grep -v $nip`
        done
        OLD_DNS=`echo "$OLD_DNS" |grep -v $NEBULA_VIP`
        echo "$OLD_DNS" >> /etc/resolv.conf
    fi
    cat /etc/resolv.conf > /etc/resolv_app.conf
    echo "end config domain .................."
    
    #dns_daemon
    if [ -f "$APP_BASE/install/appdns.service"  ] ; then
        cat /etc/resolv.conf > /etc/resolv_app.conf
        mv -f $APP_BASE/install/appdns.service /usr/lib/systemd/system/appdns.service
        systemctl daemon-reload
        systemctl enable appdns.service
    fi
    if [ -f "$APP_BASE/install/dns_daemon.sh"  ] ; then
        mv -f $APP_BASE/install/dns_daemon.sh /etc/init.d/dns_daemon.sh
        chmod +x /etc/init.d/dns_daemon.sh
    fi
    service appdns start 2>/dev/null
fi

#vip config
echo "config vip ipconf.xml......"
$BIN/vip_config.sh

`copyAppEnvFile zookeeper`
`copyAppEnvFile registry`
`copyAppEnvFile haproxy dns`

########copy crt##############
FISRTHOST=`echo ${CLUSTER_HOST_LIST//,/ }|awk '{print $1}'`
CRT_DIR="${APP_BASE}/crt"
crtFile=`ssh $FISRTHOST ls $CRT_DIR 2>/dev/null`
if [ "$crtFile" != "" ] ; then
    mkdir -p $CRT_DIR
	scp -rp $FISRTHOST:$CRT_DIR/* $CRT_DIR/
fi
#########end crt##############

#针对此类情况: It's world writable or writable by group which is not "root"
echo " /var/log/cron
/var/log/maillog
/var/log/messages
/var/log/secure
/var/log/spooler
{
    missingok
    olddir /var/log/bak/
    daily 
    size 30M
    minsize 5M
    rotate 7
    compress 
    notifempty 
    delaycompress 
    sharedscripts
    postrotate
	/bin/kill -HUP \`cat /var/run/syslogd.pid 2> /dev/null\` 2> /dev/null || true
    endscript
}
> " /etc/logrotate.d/syslog
 
exit $?

# ifconfig enp0s3:0 10.0.0.13 netmask 255.255.255.0 up
# tracert  172.16.131.40

# echo 1 > /proc/sys/vm/drop_caches


## keepalived iptables 配置
#/sbin/iptables -A INPUT -i eth1 -d 224.0.0.0/8 -j ACCEPT
#/sbin/iptables -A INPUT -i eth1 -p 112 -j ACCEPT
# keepalived 多播包
#tcpdump -v -i eth1 host 224.0.0.18
#tcpdump -vvv -n -i eth1 host 224.0.0.18
#
#










