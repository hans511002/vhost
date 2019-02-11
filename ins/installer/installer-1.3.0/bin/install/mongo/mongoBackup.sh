#!/bin/bash
. /etc/bashrc
. $APP_BASE/install/funs.sh
BIN=$(cd $(dirname $0); pwd)


printTag()
{
   echo "usetag: <inc|full|list|clean>  [backupDir:${SHARED_PATH}/backup/mongo] [mongoHost] [mongoPort:27117] [mongoUser] [mongoPass]
        inc: Incremental backup
        full: full backup
        list: list backup files
        clean: delete all backup files
   "
   exit 1
}
backupZkNode="/mongoBackup"
if [ "$#" -lt "1" ] ; then
   printTag
   exit 1
fi

backType=$1
backupDir=$2
mongoHost=$3
mongoPort=$4
mongoUser=$5
mongoPass=$6
backupReservationDays=31

if [ "$mongoHost" != "" ] ; then
    specifyMongoHost=true
fi
if [ "$mongoPort" != "" ] ; then
    specifyMongoPort=true
fi
echo "backType=$backType"

if [ "$backType" != "inc" -a  "$backType" != "full" -a  "$backType" != "list"  -a  "$backType" != "clean"  ] ; then
   printTag
   exit 1
fi
if [ "$backupDir" = "" ] ; then
   backupDir="${SHARED_PATH}/backup/mongo"
fi
if [ "$mongoPort" = "" ] ; then
    mongoPort=27117
    #if [ "$backType" = "inc" ] ; then
    #    mongoPort=27117 # shard
    #elif [ "$backType" = "full" ] ; then
    #    mongoPort=27017 
    #fi
fi
if [ "$mongoPort" = "27017" ] ; then
   if [ "$backType" = "inc" ] ; then
      echo "only full backup with 27017"
      exit 1
   fi
fi
lastBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode  2>/dev/null `

newBackup=false
if [ "$backType" == "inc" -o  "$backType" == "full" ] ; then
newBackup=true
fi

getBackupList(){
backList=`${APP_BASE}/install/zkutil.sh ls $backupZkNode  2>/dev/null  |sed -e "s|\[||" -e "s|\]||" -e "s|, |\\n|g"|sort  `
backList=`echo $backList`
}
getBackupList
lastBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode  2>/dev/null  `
if [ "$backList" = "" -o "$lastBackInfo" = "" ] ; then
    if [ "backType" = "inc" ] ; then
        echo "not exists back info , change to Full backup "
        backType="full"
    fi
fi
if [ "$lastBackInfo" != "" ] ; then
    backupResDays=`echo "$lastBackInfo" | jq '.backupReservationDays' |sed -e "s|\"||g"`
    if [ "$backupResDays" != "" -a "$backupResDays" != "null" ] ; then
        backupReservationDays=$backupResDays
    fi
fi

dayNo=`date +%Y%m%d`
destDir="$backupDir/$dayNo"

tempDir="`date +%s`"
dockerTempDir="/var/log/mongodb/backup-$tempDir"
tempDir="${LOGS_BASE}/mongo/mongos/backup-$tempDir"

if [ "$newBackup" = "true" ] ; then
    mkdir -p $destDir
    destTime="`date +%Y%m%d%H%M%S`"
    destFileName="$destTime-$backType-$mongoPort"  
    destFilePath="$destDir/$destFileName"

    rm -rf $tempDir
    mkdir -p $tempDir
    echo "backType=$backType destDir=$destDir mongoPort=$mongoPort tempDir=$tempDir"
    echo "backList=$backList
lastBackInfo=$lastBackInfo"
    if [ "$mongoUser" = "" -a "$mongoPass" = "" ] ; then
        if [ -f  "$MONGO_HOME/mongo_cluster.conf" ] ; then
            mongoUser=`cat $MONGO_HOME/mongo_cluster.conf|grep -E "^mongoUser="|awk -F= '{print $2}'`
            mongoPass=`cat $MONGO_HOME/mongo_cluster.conf|grep -E "^mongoPasswd="|awk -F= '{print $2}'`
        fi
    fi
    if [ "$mongoUser" = "" -a "$mongoPass" = "" ] ; then
        if [  -f  "$HIVECORE_HOME/sobeyhive_config/sobeyhive_application_all_config.properties" ] ; then
            mongoUserInfo=`cat $HIVECORE_HOME/sobeyhive_config/sobeyhive_application_all_config.properties |grep "^mongo.credentials=" |awk -F= '{print $2}'`
            #mongo.credentials=sobeyhive:$0bEyHive*2o1Six@admin
            mongoUser=`echo "$mongoUserInfo"| sed -e "s|:.*||" `
            mongoUserInfo=`echo "$mongoUserInfo"| sed -e "s|$mongoUser:||" `
            mongoDb=`echo "$mongoUserInfo"| sed -e "s|.*@||" `
            mongoPass=`echo "$mongoUserInfo"| sed -e "s|@mongoDb||" `
        fi
    fi
    #if [ "$mongoUser" = "" ] ; then
    #    mongoUser="sobeyhive"
    #fi
    #if [ "$mongoPass" = "" ] ; then
    #    mongoPass='$0bEyHive*2o1Six'
    #fi
fi


if [ "$specifyMongoHost" != "true" ] ; then
   mongoHosts=`cat ${APP_BASE}/mongo-3.4.6/conf/servers`
    mongoHost="`hostname`"
    for HOST in b ; do
        if [ "`testHostPort $HOST $mongoPort `"  = "open" ] ; then
            mongoHost=$HOST
            if [ "`hostname`" = "$HOST" ] ; then
               break
            fi
        fi
    done
fi


HOSTNAME="`hostname`"

deleteBackupFiles()
{
    echo " delete history bakcup files ... "
    days=0;
    deleteDayNo="$dayNo"
    while [ "$days"  -lt "$backupReservationDays" ] ; do
        deleteDayNo=`get_before_date $deleteDayNo`
        ((days++))
    done
    echo "deleteDayNo=$deleteDayNo"

    getBackupList
    echo "backList=$backList"
    backDirSame=false
    for backNode in $backList ; do
        lastBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode/$backNode  2>/dev/null `
        backType=`echo "$lastBackInfo"|jq '.backType'  |sed -e "s|\"||g"`
        backTime=`echo "$lastBackInfo"|jq '.backTime'  |sed -e "s|\"||g"`
        backFile=`echo "$lastBackInfo"|jq '.backFile'  |sed -e "s|\"||g"`
        fileSize=`echo "$lastBackInfo"|jq '.fileSize'  |sed -e "s|\"||g"`
        lastBackTS=`echo "$lastBackInfo"|jq '.lastBackTS'  |sed -e "s|\"||g"`
        mongoBackupDesc=`echo "$lastBackInfo"|jq '.backupDesc'  |sed -e "s|\"||g" `
        lastBackStr=`echo $lastBackTS|awk -F: '{print $1}'  |sed -e "s|\"||g" `
        echo "check: $backType  $backTime    $backFile      $lastBackTS( `todate $lastBackStr`) $fileSize  $mongoBackupDesc"
        backDay="${backTime:0,8}"
        backDay=`expr substr $backTime 1 8`
        if [ "$backDay" -lt "$deleteDayNo" ] ; then
            echo "rm -rf   $backFile "
            rm -rf   $backFile
        fi
        if [ "$backDirSame" = "false" -a "${backFile//$backupDir\//}" != "$backFile" ] ; then
            backDirSame=true
        fi
        if [ ! -f  "$backFile" ] ; then
            echo "file not exists:$backFile  delete zkNode $backupZkNode/$backNode"
            ${APP_BASE}/install/zkutil.sh rmr $backupZkNode/$backNode  2>/dev/null
        fi
    done
    backList=`echo "$backList" | sed -e "s|  | |g" -e "s| |,|g" `
    backList=",$backList,"
   # echo "backList=$backList"
    if [ "$backDirSame" = "true" ] ; then
        hisBackFiles=` find $backupDir -name "*.tar.gz" `
        for backFile in $hisBackFiles ; do
            backFileName=`echo $backFile |sed -e "s|.*/||" -e "s|.tar.gz||"`
            if [ "${backList//,$backFileName,/}" = "$backList" ] ; then
                echo "file $backFile not in zk list, delete it"
                echo "rm -rf $backFile"
                rm -rf $backFile
            fi
        done
    fi
}


# 全量备份
fullBackup()
{
    backTimeStartStamp=`date +%s`
    mongoOpts=" --oplog "
    if [ "$mongoPort" = "27017" ] ; then
       mongoOpts=""
    fi

    if [ "$mongoUser" != "" -a "$mongoPass" != "" ] ; then
       mongoOpts="$mongoOpts -u \"$mongoUser\" $mongoOpts -p \"$mongoPass\" --authenticationDatabase admin "
    fi
    echo "docker exec -i  mongo-mongos-$HOSTNAME mongodump --host $mongoHost --port $mongoPort  $mongoOpts -o $dockerTempDir"
    docker exec -i  mongo-mongos-$HOSTNAME mongodump --host $mongoHost --port $mongoPort  $mongoOpts -o $dockerTempDir
    if [ "$?" != "0" ] ; then
       echo "failed:dump data from $mongoHost failed
        docker exec -i  mongo-mongos-$HOSTNAME mongodump --host $mongoHost --port $mongoPort  $mongoOpts -o $dockerTempDir
        "
       exit 1
    fi
    backTimeEndStamp=`date +%s`
    echo "cd $tempDir; tar zcf $destFilePath.tar.gz * "
    cd $tempDir
    if [ "$mongoPort" = "27017" ] ; then
        rm -rf config
    else
        rm -rf admin
    fi
    tar zcf $destFilePath.tar.gz *
    oplogFile="oplog.bson"
    oplogSize=0
    if [ -f "$oplogFile" ] ; then
        oplogSize=` du -b $oplogFile|awk '{print $1}'`
    fi

    if [ "$oplogSize" = "0"  ] ; then
        lastTs=$backTimeStartStamp
        lastTsi=0
    else
        #backTimeEndStamp=`date +%s`
        #echo "full oplog is empty , dump oplog.rs "
        #echo "docker exec -i  mongo-mongos-$HOSTNAME mongodump --host $mongoHost --port $mongoPort  $mongoOpts    -d local -c oplog.rs  -o $dockerTempDir --query=\"{ \\\"ts\\\": { \\\$gt: Timestamp($backTimeStartStamp, 0) }, \\\$and: [ {\\\"ts\\\": { \\\$lte: Timestamp($backTimeEndStamp, 0) } }]}\" "
        #docker exec -i  mongo-mongos-$HOSTNAME mongodump --host $mongoHost --port $mongoPort   $mongoOpts  -d local -c oplog.rs  -o $dockerTempDir --query="{ \"ts\": { \$gt: Timestamp($backTimeStartStamp, 0) }, \$and: [ { \"ts\": { \$lte: Timestamp($backTimeEndStamp, 0)} } ]}"
        #
        #
        ##{ "ts": { $gte: Timestamp(0, 0) }, $and: [ { "ts": { $lte: Timestamp(0, 0) } } ] }
        #
        #oplogFile="local/oplog.rs.bson"
        #oplogSize=` du -b $oplogFile |awk '{print $1}'`

        lastOplogInfo=`docker exec -i  mongo-mongos-$HOSTNAME bsondump $dockerTempDir/$oplogFile |grep -v "objects found"|tail -n 1 `

        lastTs=`echo "$lastOplogInfo" |sed -e  's|\\$||g' | jq '.ts.timestamp.t'`
        lastTsi=`echo "$lastOplogInfo" |sed -e  's|\\$||g' | jq '.ts.timestamp.i'`
        if [ "$lastTs" = "" ] ; then
           lastTs="$backTimeEndStamp"
        fi
        if [ "$lastTsi" = "" ] ; then
           lastTsi=1
        fi
    fi

    cd $BIN
    backFileSize=`du -b $destFilePath.tar.gz|awk '{print $1}'`
    lastBackTS="$lastTs:$lastTsi"
    rm -rf $tempDir
    lastBackInfo=""
    if [ "$backList" = "" ] ; then
        echo "${APP_BASE}/install/zkutil.sh create $backupZkNode  \"\""
        ${APP_BASE}/install/zkutil.sh create $backupZkNode  \"\"
    fi
    lastBackInfo=""
    shardInfoVal=""
    #if [ "$mongoPort" != "27017" ] ; then
    #fi
    shardInfoVal="{\"backType\":\"$backType\",\"lastBackTS\":\"$lastBackTS\",\"mongoPort\":\"$mongoPort\",\"mongoHost\":\"$mongoHost\"}"
    
    while [ "$lastBackInfo" = "" ] ; do
        echo "${APP_BASE}/install/zkutil.sh create $backupZkNode/$destFileName  '{\"backType\":\"$backType\",\"backTime\":\"$destTime\",\"backFile\":\"$destFilePath.tar.gz\",\"fileSize\":\"$backFileSize\",\"lastBackTS\":\"$lastBackTS\",\"mongoPort\":\"$mongoPort\",\"mongoHost\":\"$mongoHost\",\"backupDesc\":\"$mongoBackupDesc\"}'"
        ${APP_BASE}/install/zkutil.sh create $backupZkNode/$destFileName  "{\"backType\":\"$backType\",\"backTime\":\"$destTime\",\"backFile\":\"$destFilePath.tar.gz\",\"fileSize\":\"$backFileSize\",\"lastBackTS\":\"$lastBackTS\",\"mongoPort\":\"$mongoPort\",\"mongoHost\":\"$mongoHost\",\"backupDesc\":\"${mongoBackupDesc// /}\"}"
        lastBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode/$destFileName  2>/dev/null  `
    done
    echo -e "update zk node $backupZkNode/$destFileName   value to :\n `echo "$lastBackInfo"|jq '.'`"
    lastBackInfo=""
    lastRootBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode` 
    if [ "$lastRootBackInfo" = "" ] ; then
        lastRootBackInfo="{}"
    fi 
    lastRootBackInfo=`echo "$lastRootBackInfo" | jq ' setpath(["'$mongoPort'"]; '$shardInfoVal') | setpath(["backType"]; "'$backType'") | setpath(["lastTime"]; "'$destTime'") | setpath(["lastBackTS"]; "'$lastBackTS'") | setpath(["mongoPort"]; "'$mongoPort'") | setpath(["mongoHost"]; "'$mongoHost'") | setpath(["backupDesc"]; "'${mongoBackupDesc// /}'") | setpath(["backupReservationDays"]; "'$backupReservationDays'") ' `
    lastRootBackInfo=`echo $lastRootBackInfo | sed -e 's| ||g'`
    echo "update $backupZkNode to $lastRootBackInfo"
    echo "$lastRootBackInfo"|jq '.'
    
   # exit 1
    
    while [ "$lastBackInfo" = "" ] ; do
        echo "${APP_BASE}/install/zkutil.sh set $backupZkNode '$lastRootBackInfo' "
        ${APP_BASE}/install/zkutil.sh set $backupZkNode "\"$lastRootBackInfo\""
        lastBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode  2>/dev/null `
    done
    echo -e "update zk node $backupZkNode  value to :\n `echo "$lastBackInfo"|jq  '.'`"

    deleteBackupFiles
    listBackup
}


# 增量备份
incBackup()
{
    backTimeStartStamp=""
    # backupResDays=`echo "$lastBackInfo" | jq '.backupReservationDays' |sed -e "s|\"||g"`
    # if [ "$backupResDays" != "" ] ; then
    #     backupReservationDays=$backupResDays
    # fi
    # echo "$lastBackInfo" | jq  '."27117"'
    backTimeStartStamp=`echo "$lastBackInfo" | jq '."'$mongoPort'".lastBackTS' |sed -e "s|\"||g"`
    echo "backTimeStartStamp=$backTimeStartStamp"
    # exit 1
    if [ "$backTimeStartStamp" = "" ] ; then
        backTimeStartStamp=`echo "$lastBackInfo" | jq '.lastBackTS' |sed -e "s|\"||g"`
    fi 
    
    lastTs=`echo "$backTimeStartStamp"|awk -F: '{print $1}'  `
    lastTsi=`echo "$backTimeStartStamp"|awk -F: '{print $2}'  `

    if [ "$mongoUser" != "" -a "$mongoPass" != "" ] ; then
       mongoOpts="$mongoOpts -u \"$mongoUser\" $mongoOpts -p \"$mongoPass\" --authenticationDatabase admin "
    fi
    
    echo "docker exec -i  mongo-mongos-$HOSTNAME mongodump --host $mongoHost --port $mongoPort  $mongoOpts  -d local -c oplog.rs -o $dockerTempDir --query=\"{ \\\"ts\\\": { \\\$gt: Timestamp($lastTs, $lastTsi) }, \\\"op\\\": { \\\$ne: \\\"n\\\" } } "
    docker exec -i  mongo-mongos-$HOSTNAME mongodump --host $mongoHost --port $mongoPort   $mongoOpts   -d local -c oplog.rs -o $dockerTempDir --query="{ \"ts\": { \$gt: Timestamp($lastTs, $lastTsi) }, \"op\": { \$ne: \"n\" } }"
    if [ "$?" != "0" ] ; then
       echo ""
       exit 1
    fi
    backTimeEndStamp=`date +%s`
    echo "cd $tempDir; tar zcf $destFilePath.tar.gz * "
    cd $tempDir
    tar zcf $destFilePath.tar.gz *
    backFileSize=`du -b $destFilePath.tar.gz|awk '{print $1}'`
    echo "inc backup mongo oplog to $destFilePath.tar.gz"
    oplogFile="local/oplog.rs.bson"
    oplogSize=` du -b $oplogFile|awk '{print $1}'`
    if [ "$oplogSize" -gt "0"  ] ; then
        lastOplogInfo=`docker exec -i  mongo-mongos-$HOSTNAME bsondump $dockerTempDir/$oplogFile |grep -v "objects found"|tail -n 1 `
        lastTs=`echo "$lastOplogInfo" |sed -e  's|\\$||g' | jq '.ts.timestamp.t'`
        lastTsi=`echo "$lastOplogInfo" |sed -e  's|\\$||g' | jq '.ts.timestamp.i'`
        if [ "$lastTs" = "" ] ; then
           lastTs="$backTimeEndStamp"
        fi
        if [ "$lastTsi" = "1" ] ; then
           lastTsi=1
        fi
        cd $BIN

        lastBackTS="$lastTs:$lastTsi"
        echo "last back ts $lastBackTS"
        rm -rf $tempDir
        lastBackInfo=""
        shardInfoVal=""
        #if [ "$mongoPort" != "27017" ] ; then
        #fi
        shardInfoVal="{\"backType\":\"$backType\",\"lastBackTS\":\"$lastBackTS\",\"mongoPort\":\"$mongoPort\",\"mongoHost\":\"$mongoHost\"}"
        
        while [ "$lastBackInfo" = "" ] ; do
            echo "${APP_BASE}/install/zkutil.sh create $backupZkNode/$destFileName '{\"backType\":\"$backType\",\"backTime\":\"$destTime\",\"backFile\":\"$destFilePath.tar.gz\",\"fileSize\":\"$backFileSize\",\"lastBackTS\":\"$lastBackTS\",\"mongoPort\":\"$mongoPort\",\"mongoHost\":\"$mongoHost\",\"backupDesc\":\"$mongoBackupDesc\"}' "
            ${APP_BASE}/install/zkutil.sh create $backupZkNode/$destFileName "{\"backType\":\"$backType\",\"backTime\":\"$destTime\",\"backFile\":\"$destFilePath.tar.gz\",\"fileSize\":\"$backFileSize\",\"lastBackTS\":\"$lastBackTS\",\"mongoPort\":\"$mongoPort\",\"mongoHost\":\"$mongoHost\",\"backupDesc\":\"${mongoBackupDesc// /}\"}"
            lastBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode/$destFileName  2>/dev/null `
        done
        echo -e "update zk node $backupZkNode/$destFileName   value to :\n" `echo "$lastBackInfo"|jq  '.'`
        lastBackInfo=""
        lastRootBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode`
        if [ "$lastRootBackInfo" = "" ] ; then
            lastRootBackInfo="{}"
        fi 
        lastRootBackInfo=`echo "$lastRootBackInfo" | jq ' setpath(["'$mongoPort'"]; '$shardInfoVal')| setpath(["backupReservationDays"]; "'$backupReservationDays'") | setpath(["backType"]; "'$backType'") | setpath(["lastTime"]; "'$destTime'") | setpath(["lastBackTS"]; "'$lastBackTS'") | setpath(["mongoPort"]; "'$mongoPort'") | setpath(["mongoHost"]; "'$mongoHost'") | setpath(["backupDesc"]; "'${mongoBackupDesc// /}'") ' `
        lastRootBackInfo=`echo $lastRootBackInfo | sed -e 's| ||g'`
        echo "update $backupZkNode to $lastRootBackInfo"
        echo "$lastRootBackInfo"|jq '.'

        while [ "$lastBackInfo" = "" ] ; do
            echo "${APP_BASE}/install/zkutil.sh set $backupZkNode '$lastRootBackInfo' "
            ${APP_BASE}/install/zkutil.sh set $backupZkNode "\"$lastRootBackInfo\""
            lastBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode  2>/dev/null `
        done
        echo -e "update zk node $backupZkNode  value to :\n" `echo "$lastBackInfo"|jq  '.'`
        deleteBackupFiles
    else
        rm -rf $tempDir  $destFilePath.tar.gz
        echo "not have oplog record ,skip this back"
        deleteBackupFiles
    fi
    listBackup
}

listBackup()
{
clean=$1
echo "list backupFiles"
getBackupList
echo "backType  backTime    backFile                                         lastBackTS             fileSize   backupDesc"
for backNode in $backList ; do
    lastBackInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode/$backNode  2>/dev/null `
    backType=`echo "$lastBackInfo"|jq '.backType'  |sed -e "s|\"||g"`
    backTime=`echo "$lastBackInfo"|jq '.backTime'  |sed -e "s|\"||g" `
    backFile=`echo "$lastBackInfo"|jq '.backFile'  |sed -e "s|\"||g" `
    fileSize=`echo "$lastBackInfo"|jq '.fileSize'  |sed -e "s|\"||g" `
    lastBackTS=`echo "$lastBackInfo"|jq '.lastBackTS'  |sed -e "s|\"||g" `
    mongoBackupDesc=`echo "$lastBackInfo"|jq '.backupDesc'  |sed -e "s|\"||g" `
    lastBackStr=`echo $lastBackTS|awk -F: '{print $1}'  |sed -e "s|\"||g" `
    if [ "$backType" = "inc" ] ; then
       backType="inc "
    fi
    echo "$backType  $backTime    $backFile     $lastBackTS(`todate $lastBackStr`)      $fileSize  $mongoBackupDesc"
    if [ "$clean" = "clean" ] ; then
        echo "delete file: $backFile"
        if [ -f  "$backFile" ] ; then
            rm -rf $backFile
        fi
        ${APP_BASE}/install/zkutil.sh rmr $backupZkNode/$backNode  2>/dev/null
    fi
done
}

if [ "$backType" = "full" ] ; then
fullBackup
elif [ "$backType" = "inc" ] ; then
incBackup
elif [ "$backType" = "list" ] ; then
listBackup
elif [ "$backType" = "clean" ] ; then
listBackup  clean
fi







#docker exec -i  mongo-mongos-hivenode01 mongodump --authenticationDatabase admin --host 172.16.131.136 --port 27117  -u 'sobeyhive' -p '$0bEyHive*2o1Six'  --oplog -o $dockerTempDir




