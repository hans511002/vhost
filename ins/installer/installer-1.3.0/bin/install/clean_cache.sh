#!/bin/bash

. /etc/bashrc
bin=$(cd $(dirname $0); pwd)

#codis need
function zkClient(){

    zookeeperHostList=${zookeeper_hosts//,/ }
    for host in $zookeeperHostList; do
        
        zkStatus=`ssh $host "zk_status" >/dev/null 2>&1; echo $?`
        if [ "$zkStatus" -eq "0" ]; then   
            zookeeperHost=$host
            break
        fi
    done

zkCMD=$@
ssh $zookeeperHost "\$ZOOKEEPER_HOME/bin/zkCli.sh -server \$ZOOKEEPER_URL 2>/dev/null" <<EOF

$zkCMD

EOF
}

#redis
function clean_redis() {
if [ -n "$redis_hosts" ]; then
    appHosts=${redis_hosts//,/ }
    for host in $appHosts; do
        sentinelInfo=$(ssh $host "\$REDIS_HOME/bin/redis-cli -p 6390 info" | grep 'master0:name=mymaster' | sed "s/\r//")
        echo "sentinelInfo: $sentinelInfo"

        sentinelStatus=$(echo "$sentinelInfo" | awk -F ',' '{print $2}' | awk -F '=' '{print $2}')
        if [ "$sentinelStatus" != "ok" ]; then
            echo "[ERROR]: status=$sentinelStatus"
            exit 1
        fi

        masterNode=$(echo "$sentinelInfo" | awk -F ',' '{print $3}' | awk -F '[=:]' '{print $2}')
        if [ "$masterNode" != "" ]; then
            echo masterNode=$masterNode
            break
        fi
    done
    [[ "$masterNode" != "" ]] || (echo "[ERROR] Get redis master node failed" && exit 1) || exit 1
    
    #clean
    cacheData=`ssh $masterNode "\$REDIS_HOME/bin/redis-cli -p 6389 KEYS \*"`
    echo -e "clean redis cache: \n$cacheData" && sleep 0.5
    ssh $masterNode "\$REDIS_HOME/bin/redis-cli -p 6389 FLUSHALL"
fi
}

#codis
function clean_codis() {
if [ -n "$codis_hosts" ]; then
    if [ -n "$redis_hosts" ]; then
        appHosts=${codis_hosts//,/ }
        for host in $appHosts; do
            codisServersID=${host}:6379
            codisServersStatus=`zkClient get /zk/codis/db_test/servers/group_1/$codisServersID`
            codisServersStatus=$(echo ${codisServersStatus##*path:null})
            [[ -n "$codisServersStatus" ]] || (echo "[ERROR] Get $codisServersID zkdata failed" && exit 1 ) || return 1

            if [ "${codisServersStatus//offline/ }" != "${codisServersStatus}" ]; then
                echo "$host ===> [warning] The $codisServersID is not online"
                continue
            fi

            if [ "${codisServersStatus//master/ }" != "${codisServersStatus}" ];then
                codisMasterServer=$codisServersID
                masterNode=$host
                break
            fi
        done
        [[ "$masterNode" != "" ]] || (echo "[ERROR] Get codis master node failed" && exit 1) || exit 1
        
        #clean
        cacheData=`ssh $masterNode "\$REDIS_HOME/bin/redis-cli -p 6379 KEYS \*"`
        echo -e "clean codis cache: \n$cacheData" && sleep 0.5
        ssh $masterNode "\$REDIS_HOME/bin/redis-cli -p 6379 FLUSHALL"        
    else
        appHosts=${codis_hosts//,/ }
        for host in $appHosts; do
            ssh $host "\$CODIS_HOME/sbin/stop_codis_cluster.sh"
            break
        done
        
        for host in $appHosts; do
            ssh $host "rm -rf ${DATA_BASE}/codis/dumpa.rdb"
            sleep 0.5
        done
        
        for host in $appHosts; do
            ssh $host "\$CODIS_HOME/sbin/start_codis_cluster.sh"
            break
        done        
    fi
fi
}

function hivecore() {
CMD=$1
if [ -n "$hivecore_hosts" ]; then
    appHosts=${hivecore_hosts//,/ }
    for host in $appHosts; do
        if [ -n "ssh $host 'which '${CMD}'_hivecore_cluster.sh 2>/dev/null'" ]; then
            ssh $host "${CMD}_hivecore_cluster.sh"
            break
        fi
    done
fi
}

function hivepmp() {
CMD=$1
if [ -n "$hivepmp_hosts" ]; then
    appHosts=${hivepmp_hosts//,/ }
    for host in $appHosts; do
        if [ -n "ssh $host 'which '${CMD}'_hivepmp_cluster.sh 2>/dev/null'" ]; then
            ssh $host "${CMD}_hivepmp_cluster.sh"
            break
        fi
    done
fi
}

#clean
# if [ "$1" = "hivecore" ]; then
    # hivecore stop
    # clean_redis
    # clean_codis
    # hivecore start
# elif [ "$1" = "hivepmp" ]; then
    # hivepmp stop
    # clean_redis
    # clean_codis
    # hivepmp start
# elif [ "$1" = "all" ]; then
    # hivecore stop
    # hivepmp stop
    # clean_redis
    # clean_codis
    # hivecore start
    # hivepmp start
# else
    # echo "Usage: $0 {hivecore|hivepmp|all}"
    # exit 1
# fi

#clean
# if [ "$1" = "redis" ]; then
    # clean_redis
# elif [ "$1" = "codis" ]; then
    # clean_codis
# elif [ "$1" = "all" ]; then
    # clean_redis
    # clean_codis
# else
    # echo "Usage: $0 {redis|codis|all}"
    # exit 1
# fi

hivecore stop
hivepmp stop
clean_redis
# clean_codis
hivecore start
hivepmp start



