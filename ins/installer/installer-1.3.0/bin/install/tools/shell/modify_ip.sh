#!/bin/bash
#author: hehaiqiang
#修改集群所有主机，任意一台执行即可
#参数说明：$1:源IP, $2:目的IP， 多个以英文分号/空格/逗号隔开，$1里ip数量必须等于$2里ip数量，排序一致
#Usage: modify_ip.sh "172.16.131.131" "172.16.131.231"
#Usage: modify_ip.sh "172.16.131.131;172.16.131.132;172.16.131.133" "172.16.131.231;172.16.131.232;172.16.131.233"
#VRID: tcpdump -nn -i any net 224.0.0.0/8

. /etc/bashrc
bin=$(cd $(dirname $0); pwd)
modifyDate=`date "+%Y%m%d_%H%M%S"`

if [ "$#" -ne "2" ]; then
    echo "Usage: $0 \"\$1\" \"\$2\""
    exit 1
fi

function testHostPort(){
    if [ "`which tcping >/dev/null 2>&1;echo $?`" = "0" ]; then
        tcping -t 2 "$@" 2>&1 |sed -e 's|.*open.|open|' -e 's|.*closed.|closed|'
    else
        sshPortStatus=$(nmap $1 -p $2 --disable-arp-ping | grep "$2/tcp" | awk '{print $2}')
        if [ "$sshPortStatus" = "filtered" -o "$sshPortStatus" = "open" ]; then
            echo "open"
        fi
    fi
}

srcCnts=$1
dstCnts=$2

srcCnts=(`echo "$srcCnts" | awk -F '[,; ]+' '{$1=$1; print $0}'`)
dstCnts=(`echo "$dstCnts" | awk -F '[,; ]+' '{$1=$1; print $0}'`)
sum=${#srcCnts[@]}
appHosts=${CLUSTER_HOST_LIST//,/ }

if [ "${#srcCnts[@]}" != "${#dstCnts[@]}" ]; then
    echo "${#srcCnts[@]} != ${#dstCnts[@]}"
    exit 1
fi

for ((i=0; i<$sum; i++)); do
    srcCnt=${srcCnts[$i]}
    dstCnt=${dstCnts[$i]}
    echo -e "\033[1;36m${srcCnt} ===> ${dstCnt}\033[0m"
done

echo -e -n "\033[1;32mAre you sure to modify the above content (y/n)[n]:\033[0m "
read answer
if [ "$answer" != "y" ]; then
    exit 0
fi

#先修改本机/etc/hsots文件，在远程修改其他节点/etc/hosts文件
for ((i=0; i<$sum; i++)); do
    srcCnt=${srcCnts[$i]}
    dstCnt=${dstCnts[$i]}
    echo -e "\033[35m$(hostname):/etc/hosts\033[0m\033[36m:\033[0m \033[33m${srcCnt} ===> ${dstCnt}\033[0m"
    sed -i "s/${srcCnt//./\\.}/${dstCnt}/g" /etc/hosts
done

for ((i=0; i<$sum; i++)); do
    srcCnt=${srcCnts[$i]}
    dstCnt=${dstCnts[$i]}
    for host in ${appHosts}; do
        if [ "$host" = "$(hostname)" ]; then
            continue
        fi
        ssh $host "echo -e \"\033[35m${host}:/etc/hosts\033[0m\033[36m:\033[0m \033[33m${srcCnt} ===> ${dstCnt}\033[0m\"" 
        ssh $host "sed -i \"s/${srcCnt//./\\.}/${dstCnt}/g\" /etc/hosts"
    done
done
    
#host解析错误或某节点无法访问时退出
for host in ${appHosts}; do
    sshPortStatus=`testHostPort $host 22`
    if [ "$sshPortStatus" != "open" ]; then
        echo "$host: port 22 closed, please check and retry"
        exit 1
    fi
done

#确保所有apps被关闭
for host in ${appHosts}; do
    echo -e "\033[1;34m${host} ===> Checking apps status...\033[0m"
    dockerStatus=`ssh $host "systemctl status docker >/dev/null 2>&1"; echo $?`
    if [ "$dockerStatus" = "0" ]; then
        echo "$host ===> You must stop all apps. use cmd: sobeyhive_stop_all.sh"
        exit 1
    fi
done

needModifyDirs="
/etc/
${APP_BASE}/
/var/named/
"

tmpFile="/tmp/modifyIP.txt"
logFile="/tmp/modifyIP.log.${modifyDate}"

stop_hive_autostart.sh all > /dev/null 2>&1

#停止named: 先停slave，后停master
# str1=$(echo ${PRODUCT_DOMAIN} | awk -F '.' '{print $1}')
# str2=${PRODUCT_DOMAIN##$str1.}

# if [ -n "$dns_hosts" ]; then
    # dnsHosts=${dns_hosts//,/ }
    # for host in $dnsHosts; do
        # cnt=$(ssh $host "grep -r 'type slave' /etc/named/${str2}.key")
        # if [ -n "$cnt" ]; then
            # ssh $host "service named stop >/dev/null 2>&1"
            # continue
        # fi
        # masters="$masters $host"
    # done

    # if [ -n "$masters" ]; then
        # for host in $masters; do
            # ssh $host "service named stop >/dev/null 2>&1"
        # done
    # fi
# else
    # for host in $appHosts; do
        # cnt=$(ssh $host "grep -r 'type slave' /etc/named/${str2}.key")
        # if [ -n "$cnt" ]; then
            # ssh $host "service named stop >/dev/null 2>&1"
            # continue
        # fi
        # masters="$masters $host"
    # done

    # if [ -n "$masters" ]; then
        # for host in $masters; do
            # ssh $host "service named stop >/dev/null 2>&1"
        # done
    # fi
# fi

if [ -n "$dns_hosts" ]; then
    dnsHosts=${dns_hosts//,/ }
    for host in $dnsHosts; do
        ssh $host "service hivedns stop >/dev/null 2>&1" 
        ssh $host "service named stop >/dev/null 2>&1"
    done
fi

for host in $appHosts; do

    echo -e "\033[1;34m${host} ===> Checking, please wait...\033[0m"
    sleep 2

    ssh $host "cat /dev/null > $logFile"
    for ((i=0; i<$sum; i++)); do
        srcCnt=${srcCnts[$i]}
        dstCnt=${dstCnts[$i]}
        ssh $host "cat /dev/null > $tmpFile"
        for dir in $needModifyDirs; do
            if [ -d "$dir" ]; then
                ssh $host "find $dir -type f -size -10240k | grep -E \"\.xml$|\.cfg$|\.conf$|\.sh$|\.properties$|\.config$|\.js$|\.json$|\.cnf|hosts$|\.yml$|\.zone$|\.dns$\" | xargs grep \"${srcCnt//./\\.}\" 2>/dev/null | awk -F ':' '{print \$1}' | uniq >> $tmpFile"
            fi
        done

        for file in `ssh $host "cat $tmpFile"`; do
            ssh $host "echo -e \"\033[35m${host}:$file\033[0m\033[36m:\033[0m \033[33m${srcCnt} ===> ${dstCnt}\033[0m\" | tee -a $logFile"
            ssh $host "sed -i \"s/${srcCnt//./\\.}/${dstCnt}/g\" $file"
            sleep 0.02
        done
        ssh $host "rm -rf $tmpFile"
    done
done

#启动named: 先启master，后启slave

# str1=$(echo ${PRODUCT_DOMAIN} | awk -F '.' '{print $1}')
# str2=${PRODUCT_DOMAIN##$str1.}

# if [ -n "$dns_hosts" ]; then
    # dnsHosts=${dns_hosts//,/ }
    # for host in $dnsHosts; do
        # cnt=$(ssh $host "grep -r 'type master' /etc/named/${str2}.key")
        # if [ -n "$cnt" ]; then
            # ssh $host "service named start >/dev/null 2>&1"
            # continue
        # fi
        # slaves="$slaves $host"
    # done

    # if [ -n "$slaves" ]; then
        # for host in $slaves; do
            # ssh $host "service named start >/dev/null 2>&1"
        # done
    # fi
# else
    # for host in $appHosts; do
        # cnt=$(ssh $host "grep -r 'type master' /etc/named/${str2}.key")
        # if [ -n "$cnt" ]; then
            # ssh $host "service named start >/dev/null 2>&1"
            # continue
        # fi
        # slaves="$slaves $host"
    # done

    # if [ -n "$slaves" ]; then
        # for host in $slaves; do
            # ssh $host "service named start >/dev/null 2>&1"
        # done
    # fi
# fi

if [ -n "$dns_hosts" ]; then
    dnsHosts=${dns_hosts//,/ }
    for host in $dnsHosts; do
        ssh $host "service named start >/dev/null 2>&1"
        ssh $host "service hivedns start >/dev/null 2>&1"
    done
fi
