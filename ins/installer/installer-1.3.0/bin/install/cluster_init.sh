#!/bin/bash
. /etc/bashrc

CLS_HOST_LIST="${CLUSTER_HOST_LIST//,/ }"
# `cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'`

CRT_DIR="${APP_BASE}/install/crt"
proDomain=$(echo "$PRODUCT_DOMAIN" | awk -F. '{print $1}')
rootDomain=${PRODUCT_DOMAIN/$proDomain./}
echo "rootDomain=$rootDomain"
inExpand=false
if [ "$#" -gt "0" ] ; then
    _CLS_HOST_LIST="$1"
    inExpand=true
else
    _CLS_HOST_LIST="$CLS_HOST_LIST"
fi
echo "_CLS_HOST_LIST=$_CLS_HOST_LIST"

for HOST in ${_CLS_HOST_LIST//,/ } ; do
    echo "ssh $HOST rm -rf ${APP_BASE}/install/crt/hive_crt*"
    ssh $HOST rm -rf ${APP_BASE}/install/crt/hive_crt\*
    #if [ "hive.sobey.com" != "$rootDomain" ] ; then
    #    echo "ssh $HOST rm -rf ${APP_BASE}/install/crt/rootCA*"
    #    ssh $HOST rm -rf ${APP_BASE}/install/crt/rootCA\*
    #fi
done

for HOST in $_CLS_HOST_LIST ; do
    ssh $HOST ${APP_BASE}/install/crt_config.sh
done

#拷贝证书到每个节点
CRT_DIR="${APP_BASE}/install/crt"
for HOST in $_CLS_HOST_LIST ; do
    ssh $HOST mkdir -p /etc/haproxy/
    scp -rp $CRT_DIR $HOST:/etc/haproxy/
done

#以本机时间为准，设置其他主机时间同步
for HOST in $_CLS_HOST_LIST ; do
    [[ $HOST = "`hostname`" ]] && continue
    ssh $HOST systemctl stop ntpd 2>/dev/null
    curTime=$(date '+%Y%m%d %T')
    ssh $HOST "date -s \"$curTime\""
done

# openssl x509 -noout -text -in hive_crt.crt |grep DNS
# DNS:pf.hive.sobey.com, DNS:hive.sobey.com, IP Address:172.16.131.141

#配置本机为时间服务器
pingHOST="www.baidu.com"
NETOK=$(ping -c 1 $pingHOST |grep icmp_seq|grep time)
echo "net status ping -c 1 $pingHOST: $NETOK "
NTP_SERVERS=""
for HOST in $CLS_HOST_LIST ; do
    echo "config ntpd on $HOST"
    #允许所有主机同步
    ssh $HOST "sed -i -e 's/restrict default .*/restrict default nomodify notrap /' /etc/ntp.conf "
    ssh $HOST "sed -i -e 's/logfile .*//' /etc/ntp.conf "
    #指定NTP服务器日志文件
    #ssh $HOST "echo 'logfile /var/log/ntp' >> /etc/ntp.conf "
    ssh $HOST "sed -i '/disable monitor/a\logfile /var/log/ntp' /etc/ntp.conf "
    if [ "$NETOK" = "" -o "$NTP_SERVERS" != "" ] ; then
        ssh $HOST "sed -i -e 's/.*server cn.pool.ntp.org/#server cn.pool.ntp.org/' /etc/ntp.conf "
        ssh $HOST "sed -i -e 's/.*server 0.centos/#server 0.centos/' /etc/ntp.conf "
        ssh $HOST "sed -i -e 's/.*server 1.centos/#server 1.centos/' /etc/ntp.conf "
        ssh $HOST "sed -i -e 's/.*server 2.centos/#server 2.centos/' /etc/ntp.conf "
        ssh $HOST "sed -i -e 's/.*server 3.centos/#server 3.centos/' /etc/ntp.conf "
    else
        ssh $HOST "sed -i -e 's/.*server cn.pool.ntp.org/server cn.pool.ntp.org/' /etc/ntp.conf "
        ssh $HOST "sed -i -e 's/.*server 0.centos/server 0.centos/' /etc/ntp.conf "
        ssh $HOST "sed -i -e 's/.*server 1.centos/server 1.centos/' /etc/ntp.conf "
        ssh $HOST "sed -i -e 's/.*server 2.centos/server 2.centos/' /etc/ntp.conf "
        ssh $HOST "sed -i -e 's/.*server 3.centos/server 3.centos/' /etc/ntp.conf "
    fi
    servFlag=$(ssh $HOST "grep '^fudge 127.127.1.0' /etc/ntp.conf")
    if [ "$servFlag" = "" ] ; then
        ssh $HOST "sed -i '/.*server 3.centos.*/a\fudge 127.127.1.0 stratum 8' /etc/ntp.conf "
    fi
    servFlag=$(ssh $HOST "grep '^server 127.127.1.0' /etc/ntp.conf")
    if [ "$servFlag" = "" ] ; then
        ssh $HOST "sed -i '/.*server 3.centos.*/a\server 127.127.1.0' /etc/ntp.conf "
    fi

    NTP_SERVERS="$HOST $NTP_SERVERS"
    echo "NTP_SERVERS=$NTP_SERVERS"
    if [ "$NTP_SERVERS" != "" ] ; then
        for SER in $NTP_SERVERS ; do
            echo "config servers from ${NTP_SERVERS//$HOST/}"
            if [ "$SER" != "$HOST" ] ; then
                ssh $HOST "sed -i -e 's/server $SER//' /etc/ntp.conf "
                ssh $HOST "sed -i '/.*server 3.centos.*/a\server $SER' /etc/ntp.conf "
            fi
        done
    fi
    echo "ssh $HOST systemctl enable ntpd"
    ssh $HOST systemctl enable ntpd
    echo "ssh $HOST systemctl restart ntpd"
    ssh $HOST systemctl stop ntpd
done

CLS_HOST_LIST=($CLS_HOST_LIST)
first_host=${CLS_HOST_LIST[0]}
ssh $first_host systemctl start ntpd
for host in ${CLS_HOST_LIST[@]}; do
    [[ "$host" = "$first_host" ]] && continue
    ssh $host ntpdate $first_host 2>/dev/null
    ssh $host systemctl start ntpd
done

for host in ${CLS_HOST_LIST[@]}; do
    res=`ssh $host "cat /etc/rc.d/rc.local" | grep '^systemctl start ntpd'`
    if [ -z "$res" ]; then
        ssh $host "echo 'systemctl start ntpd' >>/etc/rc.d/rc.local"
    fi
done

#MBH不执行$APP_BASE/install/actorinstall/install.sh
# if [ ${ALL_APP//mosgateway/} = ${ALL_APP} -a ${ALL_APP//otcserver/} = ${ALL_APP} ]; then
    $APP_BASE/install/actorinstall/install.sh
# fi

/bin/stop_hive_autostart.sh all
cmd.sh rm -rf $LOGS_BASE/docker/docker_containers
exit 0



