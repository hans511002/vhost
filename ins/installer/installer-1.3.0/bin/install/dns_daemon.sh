#!/usr/bin/env bash

. /etc/bashrc
for i in /etc/profile.d/*.sh; do
    if [ -r "$i" ]; then
        if [ "$PS1" ]; then
            . "$i"
        else
            . "$i" >/dev/null
        fi
    fi
done

while true ;  do
    sleep 2
    if [ -f "/etc/resolv_app.conf" ] ; then
        if [ "`cat /etc/resolv_app.conf`" != "`cat /etc/resolv.conf`" ] ; then
            cat /etc/resolv_app.conf > /etc/resolv.conf
        fi
    fi

    [[ "${dns_hosts}" =~ "$(hostname)" ]] || continue
    [[ -n "`ps -ef | grep '/usr/sbin/named' | grep -v grep`" ]] || continue
    dnsHosts=${dns_hosts//,/ }
    dnsIPs=${dns_ips//,/ }
    proDomain=${PRODUCT_DOMAIN%%.*}
    rootDomain=${PRODUCT_DOMAIN#*.}
    priKey="vQ9U23WtJg2C9RaEItv42AaI/aECSiKW7oszg6IWQFoyQ49Rex/KRl3PWaBdLyty/ofaYhy/DxvjnP2T7HEFcw=="

    for hostIP in $dnsIPs; do
        pingStatus=false
        if [ "`ping -W 1 -c 1 $hostIP >/dev/null 2>&1; echo $?`" = "0" ]; then
            pingStatus=true
        fi

        item=`host ${PRODUCT_DOMAIN} | awk '{print $NF}' | grep $hostIP`
        if [ "$pingStatus" = "true" ];then
            if [ -n "$item" ]; then
                continue
            else
#add
nsupdate -y ${rootDomain//./}:$priKey <<EOF
server 127.0.0.1
zone $rootDomain
update add $PRODUCT_DOMAIN 5 IN A $hostIP
send
quit
EOF
            fi
        else
            if [ -n "$item" ]; then
#delete
nsupdate -y ${rootDomain//./}:$priKey <<EOF
server 127.0.0.1
zone $rootDomain
update delete $PRODUCT_DOMAIN IN A $hostIP
send
quit
EOF
            else
                continue
            fi
        fi
    done
done
