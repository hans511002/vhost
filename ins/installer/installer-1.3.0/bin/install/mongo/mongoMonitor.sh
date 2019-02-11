#! /bin/bash

if [ $# -lt 1 ] ; then
  echo "usetag:mongoMonitor.sh <stat|db> [mongos|cfgdb|shard]/dbname
  exp:mongoMonitor.sh stat mongos,cfgdb,shard 
  exp:mongoMonitor.sh db hivedb "
  exit 1
fi
. ${APP_BASE}/install/funs.sh


mongoDataType=$1
mongoDataParam="$2"

HOSTNAME=`hostname`

MONGO_FILED=".insert,.query,.update,.delete,.getmore,.command,.dirty,.used,.flushes,.vsize,.res,.qrw,.arw,.net_in,.net_out,.conn,.repl"
MONGO_MONITOR="" 
MONGO_DB_MONITOR="" 
#"docker exec -i mongo-mongos-$HOSTNAME  mongostat  --host $HOSTNAME $mongoUserOpts   -n 1 --noheaders --json "
MONGO_SED=" | sed -e 's|\*||g' -e 's|\"||g' -e 's|%||g' "

MONGO_HOSTS=",$mongo_hosts,"
#mongoDataSrc=",mongos,cfgdb,shard,"
if [ "${MONGO_HOSTS//,$HOSTNAME,/}" = "$MONGO_HOSTS" ] ; then
    for HOST in ${mongo_hosts//,/ } ; do
        mongosHost=`ssh $HOST "docker ps  |awk '{print \\\$NF}' |grep \"mongo-mongos-$HOST\""`
        if [ "$mongosHost" != "" ] ; then
            mongosHost=$HOST
            break
        fi 
    done
else
    mongosHost=$HOSTNAME
fi 

function checkMongoCons(){
if [ "$mongoDataType" = "stat" ] ; then
    mongoCons=`ssh $mongosHost docker ps |grep "mongo-"|grep "$mongosHost" |awk '{print $NF}'`
    if [ "$mongoCons" = "" ] ; then
        errorData
        exit 1
    else
        mongos=`echo "$mongoCons" |grep "\-mongos-"`
        if [ "$mongos" = "" ] ; then
            mongos=`echo "$mongoCons" |grep "\-cfg-"`
        fi
        if [ "$mongos" = "" ] ; then
            mongos=`echo "$mongoCons" |grep "\-shardrs1-"`
        fi
        if [ "$mongos" = "" ] ; then
            mongos=`echo "$mongoCons" |tail -n 1 `
        fi
        MONGO_MONITOR="docker exec -i $mongos  mongostat  --host $HOSTNAME $mongoUserOpts   -n 1 --noheaders --json "
    fi
elif [ "$mongoDataType" = "db" ] ; then
    #echo "mongosHost=$mongosHost"
    if [ "$mongosHost" = "$HOSTNAME" ] ; then
        #MONGO_DB_MONITOR="docker exec -i mongo-mongos-$mongosHost  mongo $mongoDataParam --quiet --host $mongosHost --port 27017  $mongoUserOpts "
        MONGO_DB_MONITOR="ssh $mongosHost \"docker exec -i mongo-mongos-$mongosHost  mongo $mongoDataParam --quiet --host $mongosHost --port 27017  $mongoUserOpts \""
    else
        MONGO_DB_MONITOR="ssh $mongosHost \"docker exec -i mongo-mongos-$mongosHost  mongo $mongoDataParam --quiet --host $mongosHost --port 27017  $mongoUserOpts \""
    fi 
    #echo `ssh $mongosHost "echo \"rs.status().members;\" | docker exec -i mongo-mongos-$mongosHost  mongo $mongoDataParam --host $mongosHost --port 27117 $mongoUserOpts"`
fi

}


mongoCfg=`ssh $mongosHost ls \\$MONGO_HOME/mongo_cluster.conf`
configIplist=`ssh $mongosHost cat $mongoCfg |grep configdb.iplist=| awk -F= '{print $2}'`
mongoUser=`ssh $mongosHost cat $mongoCfg |grep -E "^mongoUser="|awk -F= '{print $2}'`
mongoPass=`ssh $mongosHost cat $mongoCfg |grep -E "^mongoPasswd="|awk -F= '{print $2}'`
if [ "$mongoUser" != "" -a "$mongoPass" != "" ] ; then
    mongoUserOpts=" -u '$mongoUser'  -p '$mongoPass' --authenticationDatabase admin "
fi
shardCount=`ssh $mongosHost cat $mongoCfg |grep shardreplicaset.count=| awk -F= '{print $2}'`
shardCount=`trim "$shardCount"`
consCount=`expr $shardCount + 2`
shardIpMap=`ssh $mongosHost cat $mongoCfg |grep shardreplicaset.ipmap=| awk -F= '{print $2}'`
shardIpMap=(${shardIpMap//;/ })

checkMongoCons 

#echo mongosHost=$mongosHost

getMongoRepMaster()
{
    mongoHost=$1
    mongoPort=$2

    #masterNode=`ssh $mongoHost "echo \"rs.status().members;\" | docker exec -i mongo-mongos-$mongoHost  mongo hivedb  --quiet --host $mongoHost --port $mongoPort $mongoUserOpts" |grep -B3 "stateStr.*PRIMARY"|grep "name.*$mongoPort"|awk -F'[": ]+' '{print $3}'`
masterNode=`echo "echo \"rs.status().members;\" | docker exec -i mongo-mongos-$HOSTNAME  mongo hivedb --quiet --host $mongoHost --port $mongoPort $mongoUserOpts"|sh|grep -B3 "stateStr.*PRIMARY"|grep "name.*$mongoPort"|awk -F'[": ]+' '{print $3}'`
    if [ "$masterNode" = "" ] ; then
        echo "ssh $mongoHost 'echo \"rs.status().members;\"|docker exec -i mongo-mongos-$HOSTNAME mongo --host $mongoHost --port $mongoPort $mongoUserOpts '" >&2
        echo "masterNode is null "  >&2
        exit 1
    fi
    echo "$masterNode"
}

# echo `docker exec -ti mongo-mongos-$HOSTNAME  mongostat  --host $HOSTNAME --port 27017  -u 'sobeyhive'  -p '$0bEyHive*2o1Six' --authenticationDatabase admin -n 1 --noheaders --json| jq ".\"$HOSTNAME:27017\" | .insert,.query,.update,.delete,.getmore,.command,.flushes,.vsize,.res,.faults,.qrw,.arw,.netIn,.netOut,.conn,.set,.repl,.time,.locked,.host"` 

#echo " db.stats()"| docker exec -i mongo-mongos-hivenode01  mongo hivedb   --host hivenode01 --port 27017  -u 'sobeyhive'  -p '$0bEyHive*2o1Six' --authenticationDatabase admin

function errorData(){
if [ "$mongoDataType" = "stat" ] ; then
    if [ "${mongoDataSrc}" != "${mongoDataSrc//,mongos,/}" ] ; then
        parseMongoStatsData "mongs" 27017 ""
    fi
    if [ "${mongoDataSrc}" != "${mongoDataSrc//,cfgdb,/}" ] ; then
        parseMongoStatsData "cfgdb" 27917 ""
    fi
    if [ "${mongoDataSrc}" != "${mongoDataSrc//,shard,/}" ] ; then
        shardIdx=0
        while [ $shardIdx -lt $shardCount ] ; do 
            shardIps=${shardIpMap[$shardIdx]}
            ((shardIdx++))
            shardPort="27${shardIdx}17"
            if [ "${shardIps//,$HOSTNAME,}" != "$shardIps" ] ; then
                parseMongoStatsData "shard${shardIdx}" $shardPort "" 
            fi 
        done 
    fi
elif [ "$mongoDataType" = "db" ] ; then
    parseMongoDbStatsData $mongoDataSrc ""
fi
}


# M --master SEC - secondary  REC - recovering     UNK - unknown    SLV - slave
MONGO_RES_FILED="dbtype port master runstats insert query update delete getmore loc_cmd rep_cmd dirty used flushes vsize res qr qw ar aw net_in net_out conn repl"

#command loc_cmd|rep_cmd 
function parseMongoStatsData(){
    dataSrcType="$1"
    port="$2"
    master="$3"
    rowData="$4"
#  echo "$dataSrcType $port $master $rowData"
if [ "$rowData" = "" ] ; then
    echo "$dataSrcType,$port,$master,exit,,,,,,,,,,,,,,,,,,,,,,,,,,,,,"
    return
fi 

resRow="$dataSrcType,$port,$master,running"
idx=0 
for col in $rowData ; do
    if [ "${col//|/}" != "$col" ] ; then
        resRow="$resRow,${col//|/,}"
    else
        lchar="${col##${col%?}}"
        if [ "$col" = "null" ] ; then
            col=""
        elif [ "$lchar" = "G" -o "$lchar" = "g" ] ; then
            col=${col%?}
            col=`echo  "$col * 1024 * 1024 * 1024  "|bc |sed -e "s|\..*||" `
        elif [ "$lchar" = "M" -o "$lchar" = "m" ] ; then
            col=${col%?}
            col=`echo  "$col * 1024 * 1024  "|bc |sed -e "s|\..*||" `
        elif [ "$lchar" = "K" -o "$lchar" = "k" ] ; then
            col=${col%?}
            col=`echo  "$col * 1024 "|bc |sed -e "s|\..*||" `
        elif [ "$lchar" = "B" -o "$lchar" = "b" ] ; then
            col=${col%?}
        fi
        if [ "$idx" = "7" -o "$idx" = "6" ] ; then
            if [ "$col" = "null" -o "$col" = "" ] ; then
                col="0.0"
            else
                col=`echo  "$col * 100 "|bc `
            fi
        fi
        resRow="$resRow,$col"
    fi
    ((idx++)) 
done

echo "${resRow}"

#mongs 0 0 0 0 0 2|0 null null 0 223M 17.0M 0|0 0|0 null null 13 null
#cfgdb 0 1 1 0 0 2|0 0.0 0.0 0 1.44G 92.0M 0|0 0|0 null null 15 SEC
#shard1 0 0 0 0 0 3|0 0.0 0.0 0 1.42G 65.0M 0|0 0|0 null null 12 SEC


    
}

function parseMongoDbStatsData()
{
    echo "{\"ok\":\"-1\"}"
}
function processMongoDbStat()
{
    #checkMongoCons 
    
    #echo " echo \" db.stats();\"  |  ${MONGO_DB_MONITOR//\$/\\\$} " 
    mongoDbStats=`echo " echo \" db.stats();\"  |  ${MONGO_DB_MONITOR//\$/\\\\\$} "  |sh |sed -e "s|Timestamp.*,|\"\",|g" -e "s|ObjectId(\(.*\))|\1|g"|jq 'del(.raw)' `
    echo "$mongoDbStats" 
}

function processMongoData()
{
    mongoDataSrc=",$1,"
    shardIdx=0
    while [ $shardIdx -lt $shardCount ] ; do 
        shardIpMap[$shardIdx]=",${shardIpMap[$shardIdx]},"
        shardIps=${shardIpMap[$shardIdx]}
        echo "shardIps=$shardIps" >&2
        ((shardIdx++))
    done
    checkMongoCons
    
    #echo MONGO_MONITOR=$MONGO_MONITOR 
     
    if [ "${mongoDataSrc}" != "${mongoDataSrc//,mongos,/}" ] ; then
        echo "$MONGO_MONITOR --port 27017 | jq '.\"$HOSTNAME:27017\"| $MONGO_FILED ' $MONGO_SED" >&2
        mongsStats=`echo "$MONGO_MONITOR --port 27017 | jq '.\"$HOSTNAME:27017\"| $MONGO_FILED ' $MONGO_SED" | sh`
        parseMongoStatsData "mongs" "27017" "" "`echo $mongsStats`"
    fi 
    
    if [ "${mongoDataSrc}" != "${mongoDataSrc//,cfgdb,/}" ] ; then
        mongoCfgMaster=`getMongoRepMaster $HOSTNAME 27917`
        echo "mongoCfgMaster=$mongoCfgMaster" >&2    
        echo "$MONGO_MONITOR --port 27917 | jq '.\"$HOSTNAME:27917\"| $MONGO_FILED ' $MONGO_SED" >&2
        mongoCfgStats=`echo "$MONGO_MONITOR --port 27917 | jq '.\"$HOSTNAME:27917\"| $MONGO_FILED ' $MONGO_SED" | sh`
        parseMongoStatsData "cfgdb" "27917" "$mongoCfgMaster" "`echo $mongoCfgStats`"
    fi
    if [ "${mongoDataSrc}" != "${mongoDataSrc//,shard,/}" ] ; then
        shardIdx=0
        while [ $shardIdx -lt $shardCount ] ; do 
            shardIps=${shardIpMap[$shardIdx]}
            ((shardIdx++))
            shardPort="27${shardIdx}17"
            if [ "${shardIps//,$HOSTNAME,}" != "$shardIps" ] ; then
                mongoShardMaster=`getMongoRepMaster $HOSTNAME $shardPort`
                echo "mongoShard${shardIdx}Master=$mongoShardMaster" >&2
                echo "$MONGO_MONITOR --port $shardPort | jq '.\"$HOSTNAME:$shardPort\"| $MONGO_FILED ' $MONGO_SED" >&2
                mongoShardStats=`echo "$MONGO_MONITOR --port $shardPort | jq '.\"$HOSTNAME:$shardPort\"| $MONGO_FILED ' $MONGO_SED" | sh`
                parseMongoStatsData "shard${shardIdx}" "$shardPort" "$mongoShardMaster" "`echo $mongoShardStats`" 
            fi 
        done 
    fi
}

export tmpFile=/tmp/mongoMonitor.err
exec 4>&2
exec 2>$tmpFile
if [ "$mongoDataType" = "stat" ] ; then
    processMongoData $mongoDataParam
elif [ "$mongoDataType" = "db" ] ; then
    processMongoDbStat $mongoDataParam
fi 
exec 2>&4   # stderr back to console

