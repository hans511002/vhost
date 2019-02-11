#!/bin/bash
#author: hehaiqiang
#only for CentOS 7.x

bin=$(cd $(dirname $0); pwd)

listenPort=`ss -ntl | grep -v "State"| awk '{print $4}' | awk -F[:]+ '{print $NF}'|sort -g|uniq |awk '{printf("%s,",$0)}'|xargs echo`
reservedPorts=`sysctl net.ipv4.ip_local_reserved_ports | awk -F= '{print $NF}'`

for port in ${reservedPorts//,/ }; do

    begin=`echo $port | awk -F- '{print $1}'`
    end=`echo $port | awk -F- '{print $NF}'`

    for((i=$begin;i<=$end;i++));do

        checkStatus=`ss -ntl | grep -v "State"| awk '{print $4}' | awk -F[:]+ '{print $NF}'|sort -g|uniq | grep "^${i}$"`
        if [ -n "$checkStatus" ]; then
            echo -e "$i ==> [\033[1;31mFail\033[0m]"
            usedPort="$usedPort
$i ==> The port is already in use"
        else
            echo -e "$i ==> [\033[1;32mOk\033[0m]"
        fi
    done
done

if [ -z "$usedPort" ]; then
    echo -e "\033[1;32mCheck all port ==> Ok\033[0m"
else
    echo -e "\033[1;31mCheck failed port: $usedPort\033[0m"
fi
