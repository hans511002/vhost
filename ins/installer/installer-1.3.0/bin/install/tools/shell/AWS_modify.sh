#!/bin/bash
#author: hehaiqiang

. /etc/bashrc

#modify hostname
sleep 10
localHostname=hivenode01
for i in {1..300}; do
	if [ "`hostname`" != "$localHostname" ]; then
		hostnamectl --static set-hostname $localHostname
		sleep 1
	else
		break
	fi
done

#modify dns addr
sleep 10
dnsAddrs="
172.16.50.16

"
dnsConfig=/etc/resolv.conf
for addr in $dnsAddrs; do
    for i in {1..300}; do
        if [ -z "`sed -n '1p' $dnsConfig | grep $addr`" ]; then
            sed -i "1s/^/nameserver ${addr}\n/" $dnsConfig
            sleep 1
        else
            break
        fi
    done
done
