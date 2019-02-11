#! /bin/bash

if [ $# -lt 1 ] ; then
  echo "usetag:redisInfo.sh [type<json|row>]
  exp:mongoMonitor.sh stat mongos,cfgdb,shard 
  exp:mongoMonitor.sh db hivedb "
  exit 1
fi
. ${APP_BASE}/install/funs.sh


infoDataType=$1

#redis-cli -h hivenode01 -p 6389 info | grep -v "#"
# docker exec -ti redis-server-hivenode01 redis-cli -h hivenode01 -p 6389 info | grep -v "#"

parseRedisInfo()
{
    redisHost=$1
    redisPort=$2
    redisMasterIp=$3
    redisMasterIp="${redisMasterIp:=$redisHost}"
    redisServerInfo=`ssh $redisHost "docker exec -i redis-server-$redisHost redis-cli -h $redisMasterIp -p $redisPort info " | grep -v "#" |sed -e "s|\r||g" `
    #echo "$redisServerInfo"
    #echo "==================================" 
    if [ "$infoDataType" = "json" ] ; then
        RES_DATA="{"
        for row in $redisServerInfo ; do
            if [ "$row" = "" ] ; then
                continue 
            fi
            if [ "${row//:/}" = "${row}" ] ; then
                continue 
            fi
            key=`echo "$row" | awk -F: '{print $1}'`
            val="${row//$key:/}"
            val=`echo "$val" |sed -e "s|\r||" `
            
            #echo  "\"$key\":\"$val\""  >> /tmp/redis

            if [ "$RES_DATA" = "{" ] ; then
                RES_DATA="$RES_DATA  \"$key\":\"$val\"  "
            else
                RES_DATA="$RES_DATA  , \"$key\":\"$val\"  "
            fi
       # echo "RES_DATA=$RES_DATA"
            
        done
        if [ "$3" != "" ] ; then
            RES_DATA="$RES_DATA,\"masterIp\":\"$redisMasterIp\""
        fi 
        RES_DATA="$RES_DATA}"
        echo "$RES_DATA" | jq "."
    elif [ "$infoDataType" = "row" ] ; then
        RES_DATA=""
        for row in $redisServerInfo ; do
            if [ "$row" = "" ] ; then
                continue 
            fi
            if [ "${row//:/}" = "${row}" ] ; then
                continue 
            fi
            if [ "$RES_DATA" != "" ] ; then
                RES_DATA="$RES_DATA
$row"
            else
                RES_DATA="$row"
            fi 
        done
        echo "$RES_DATA"
        if [ "$3" != "" ] ; then
            echo "masterIp:$redisMasterIp"
        fi 
    fi
}

processRedisData()
{
    infoDataType="$1"
    #docker exec -ti redis-server-hivenode01 redis-cli -h hivenode01 -p 6389 info | grep -v "#"
    redisServerHost=$HOSTNAME
    redisCons=`docker ps |grep redis | awk '{print $NF}'`
    if [ "$redisCons" = "" ] ; then
        for HOST in ${redis_hosts//,/ } ; do
            redisCons=`ssh $HOST " docker ps |grep redis | awk '{print $NF}' "`
            if [ "$redisCons" != "" ] ; then
                redisServerHost="$HOST"
                break
            fi
        done 
    fi 
    #echo redisServerHost=$redisServerHost

    redisServerPort=`ssh $redisServerHost cat \\$REDIS_HOME/config/redis.conf | grep "^port "|awk '{print $NF}' `   #port 6389
    redisSentinelPort=`ssh $redisServerHost cat \\$REDIS_HOME/config/sentinel.conf |grep "^port "|awk '{print $NF}'`   #port 6390
    
    #echo "redisServerPort=$redisServerPort"
    #echo "redisSentinelPort=$redisSentinelPort"
    
    redisSentinelInfo=`parseRedisInfo "$redisServerHost" "$redisSentinelPort"`
    if [ "$infoDataType" = "json" ] ; then
        redisMasterIp=`echo "$redisSentinelInfo" | jq ".master0"|sed -e 's|.*address=||' -e 's|:.*||'`
        #echo "redisMasterIp=$redisMasterIp"
        redisServerInfo=`parseRedisInfo "$redisServerHost" "$redisServerPort" "$redisMasterIp"`
        echo "{\"redisServerInfo\":$redisServerInfo,\"redisSentinelInfo\":$redisSentinelInfo}"
    elif [ "$infoDataType" = "row" ] ; then
        redisMasterIp=`echo "$redisSentinelInfo" | grep "master0"|sed -e 's|.*address=||' -e 's|:.*||'`
        #echo "redisMasterIp=$redisMasterIp"
        redisServerInfo=`parseRedisInfo "$redisServerHost" "$redisServerPort" "$redisMasterIp"`
        echo "$redisServerInfo"
        echo "$redisSentinelInfo"
    fi
}

processRedisData "$infoDataType"
