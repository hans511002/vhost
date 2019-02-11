#!/bin/bash

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

#sys config
echo "vm.swappiness=0
vm.min_free_kbytes=10
vm.vfs_cache_pressure=200
vm.dirty_expire_centisecs=500
vm.dirty_background_ratio=5
vm.dirty_ratio=10
kernel.msgmnb=65536
kernel.msgmax=65536
kernel.shmmax=68719476736
kernel.shmall=4294967296
kernel.sem=5000 64000 5000 1280
fs.nr_open=104857600
fs.file-max=241741600
fs.inotify.max_queued_events=163840
fs.inotify.max_user_instances=128000
fs.inotify.max_user_watches=8192000
net.core.somaxconn=65535
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.ip_forward=1 
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1 
net.ipv4.conf.default.accept_source_route=0
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_sack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_max_orphans=327680
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_mem=786432  1048576 8388608
net.ipv4.ip_local_port_range=32768 61000
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_max_syn_backlog=262144
net.ipv4.tcp_retries2=5
net.ipv4.tcp_orphan_retries=3
net.ipv4.tcp_tw_reuse=0
net.ipv4.tcp_tw_recycle=0
net.ipv4.tcp_max_tw_buckets=360000
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_keepalive_time=180
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=5
net.core.netdev_max_backlog=262144
net.ipv4.tcp_no_metrics_save=1
net.ipv4.ip_local_reserved_ports=2181,2182,48800-48900,49991-49999,64000-64002
## iptables  参数
net.nf_conntrack_max=4194304
net.netfilter.nf_conntrack_max=4194304
#与tcp_keepalive_time有关系
net.netfilter.nf_conntrack_tcp_timeout_established=360
net.netfilter.nf_conntrack_tcp_timeout_time_wait=10
net.netfilter.nf_conntrack_tcp_timeout_close_wait=10
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=10
net.netfilter.nf_conntrack_tcp_timeout_last_ack=10
net.netfilter.nf_conntrack_tcp_timeout_syn_recv=30
net.netfilter.nf_conntrack_tcp_timeout_syn_sent=30
net.netfilter.nf_conntrack_tcp_timeout_time_wait=10
vm.overcommit_memory=1
 " >/etc/sysctl.d/sysctl.conf
#/etc/sysctl.conf

# load module
modprobe ip_conntrack
# cat /etc/sysctl.d/hive_sysctl.conf | awk -F= '{printf("%s=\"%s\"\n",$1,$2)}'|xargs  sysctl
/usr/sbin/sysctl -p /etc/sysctl.d/sysctl.conf
# sysctl -a|grep forwarding|awk -F= '{printf("%s=1\n",$1); }' |sed -e "s/ //"|xargs sysctl

if [ `cat /etc/rc.local|grep "/usr/sbin/sysctl -p /etc/sysctl.d/sysctl.conf"|wc -l ` -eq 0 ] ; then
    echo "/usr/sbin/sysctl -p /etc/sysctl.d/sysctl.conf ">>/etc/rc.d/rc.local
fi

# net.ipv4.ip_local_reserved_ports
#netstat -natp |grep LIST |awk '{print $4}'|awk -F: '{printf("%s%s%s\n"), $2,$3,$4}'|sort -g|uniq |awk '{printf("%s,",$0)}'

echo "
*               soft    core            1048576
*               hard    rss             10000
*               soft    nproc           10485760
*               hard    nproc           10485760
*               soft    nofile          1048576
*               hard    nofile          1048576
">/etc/security/limits.d/limits.conf
#/etc/security/limits.conf

ulimit -n 655350
ulimit -u 655350
ulimit -l 65536


