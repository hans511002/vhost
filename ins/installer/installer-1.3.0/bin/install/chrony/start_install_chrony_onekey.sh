#!/bin/bash

#德拓环境不升级，德拓自己维护版本
if [ -x "`which ctdb 2>/dev/null`" ]; then
    echo "`which ctdb 2>/dev/null`"
    exit 0
fi

bin=$(cd $(dirname $0); pwd)
clusterHosts=${CLUSTER_HOST_LIST//,/ }

if [ -n "`which ntpd 2>/dev/null`" ]; then
    for host in $clusterHosts; do
        ssh $host systemctl stop ntpd
        ssh $host yum remove -y ntp
        ssh $host "sed -i '/ntpd/d' /etc/rc.d/rc.local"
        ssh $host rm -rf /usr/sbin/{calc_tickadj,ntpd,ntpdc,ntp-keygen,ntpq,ntptime,ntptrace,ntp-wait,sntp,tickadj,update-leap} /usr/bin/ntpstat /etc/ntp.conf /etc/sysconfig/ntpd /usr/lib/systemd/system/ntpd.service /usr/share/ntp /var/lib/ntp
    done
fi

scp $bin/etc/chrony.conf.tmpl $bin/etc/chrony.conf
for host in $clusterHosts; do
    [[ -z "$item" ]] && item="CLUSTER_HOST_LIST"
    sed -i '/'$item'/a\#server '$host' iburst' $bin/etc/chrony.conf
    item="$host"
done

for host in $clusterHosts; do
    scp $bin/etc/chrony.conf $bin/etc/chrony.conf.$host
    chronyHosts=${clusterHosts//${host}*/}
    for i in $chronyHosts; do
        sed -i 's/^#server '${i}'.*/server '${i}' iburst/' $bin/etc/chrony.conf.$host
    done
    ssh $host yum install -y chrony ntpdate
    scp $bin/etc/chrony.conf.$host $host:/etc/chrony.conf
    ssh $host systemctl restart chronyd
    ssh $host systemctl enable chronyd
done

