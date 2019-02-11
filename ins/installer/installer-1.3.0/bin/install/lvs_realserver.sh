#!/bin/bash

. /etc/bashrc

chmod +x /etc/rc.d/init.d/functions
. /etc/rc.d/init.d/functions

case "$1" in
start)
# asset vip exists
        ipex=`ip a|grep $NEBULA_VIP |grep -v lo | wc -l`
        if [ "$ipex" = "0" ] ; then
             echo " start LVS of REALServer"
            /sbin/ifconfig lo:0 $NEBULA_VIP broadcast $NEBULA_VIP netmask 255.255.255.255 up
            /sbin/route add -host $NEBULA_VIP dev lo:0
            echo "1" >/proc/sys/net/ipv4/conf/lo/arp_ignore
            echo "2" >/proc/sys/net/ipv4/conf/lo/arp_announce
            echo "1" >/proc/sys/net/ipv4/conf/all/arp_ignore
            echo "2" >/proc/sys/net/ipv4/conf/all/arp_announce
        fi
       
        sysctl -p >/dev/null 2>&1
        echo " start LVS of REALServer [OK]"
;;
stop)
        /sbin/ifconfig lo:0 down
        echo "close LVS Directorserver"
        echo "0" >/proc/sys/net/ipv4/conf/lo/arp_ignore
        echo "0" >/proc/sys/net/ipv4/conf/lo/arp_announce
        echo "0" >/proc/sys/net/ipv4/conf/all/arp_ignore
        echo "0" >/proc/sys/net/ipv4/conf/all/arp_announce
        echo "close LVS Directorserver [OK]"
        sysctl -p >/dev/null 2>&1
;;
*)

    echo "Usage: $0 {start|stop}"
    exit 1
esac

exit 0
