#!/bin/bash
. /etc/bashrc
. $APP_BASE/install/funs.sh
BIN=$(cd $(dirname $0); pwd)

backupZkNode="/mongoBackup"

printTag()
{
    if [ "$#" != "0" ] ; then
        echo "$@"
    fi
    echo "usetag: <recovery> <backFile|backupDir> [oplogLimit(ts:0)] [mongoHost] [mongoPort] [mongoUser] [mongoPass]" 
    echo "        <dumpbson> <backFile|backupDir> <outputDir> " 
    exit 1
}

command=$1

if [ "$command" != "recovery" -a  "$command" != "dumpbson" ] ; then
    printTag
    exit 1
fi 

tempDir="${LOGS_BASE}/mongo/mongos/backup"

getMongoInfo()
{
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
}

PAUSE()
{
if [ "$#" != "0" ] ; then
    echo "$@"
fi
echo "Press any key to continue.."
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}

specifyMongoPort=false
if [ "$command" = "recovery" ] ; then
    if [ "$#" -lt "2" ] ; then
        printTag
    fi 
    backFile=$2
    oplogLimit=$3
    mongoHost=$4
    mongoPort=$5
    mongoUser=$6
    mongoPass=$7
    if [ "$mongoHost" != "" ] ; then
        specifyMongoHost=true
    fi 
    if [ "$mongoPort" != "" ] ; then
        specifyMongoPort=true
    fi 
elif [ "$command" = "dumpbson" ] ; then
    if [ "$#" -lt "3" ] ; then
        printTag
    fi 
    backFile=$2
    outputDir=$3 
fi

getMongoShardMaster()
{
    if [ "$mongoUser" != "" -a "$mongoPass" != "" ] ; then
        mongoUserOpts=" -u '$mongoUser'  -p '$mongoPass' --authenticationDatabase admin "
    fi 
    if [ "$mongoPort" = "27017" ] ; then
       masterNode=$HOSTNAME
       return
    fi

#masterNode=`ssh $mongoHost "echo \"rs.status().members;\" | docker exec -i mongo-mongos-$mongoHost  mongo hivedb --host $mongoHost --port $mongoPort $mongoUserOpts" |grep -B3 "stateStr.*PRIMARY"|grep "name.*$mongoPort"|awk -F'[": ]+' '{print $3}'`

masterNode=`echo "echo \"rs.status().members;\" | docker exec -i mongo-mongos-$HOSTNAME  mongo hivedb --host $mongoHost --port $mongoPort $mongoUserOpts"|sh|grep -B3 "stateStr.*PRIMARY"|grep "name.*$mongoPort"|awk -F'[": ]+' '{print $3}'`
    echo "=========masterNode=$masterNode==========================="
    if [ "$masterNode" = "" ] ; then
        echo "echo \"rs.status().members;\"|docker exec -i mongo-mongos-$HOSTNAME mongo --host $mongoHost --port $mongoPort $mongoUserOpts "
        echo "shard masterNode is null "
        exit 1
    fi 
}

recoveryDataBase()
{
    if [ "$oplogLimit" != "" ] ; then
        oplogLimitTS=`echo $oplogLimit|awk -F: '{print $1}'`
        oplogLimitTSi=`echo $oplogLimit|awk -F: '{print $2}'`
        if [ "${#oplogLimitTS}" != "10" ] ; then
            echo "oplogLimit format error:$oplogLimit "
            exit 1
        fi 
    fi 
    backFiles="$backFile"
    if [ -d "$backFile" ] ; then
        backFiles=`find ${SHARED_PATH}/backup/mongo/ -name "*.tar.gz"`
    fi 
    for bkFile in $backFiles ; do
        backFileName=`echo $bkFile |sed -e "s|.*/||" -e "s|.tar.gz||"`
        fileTime=`echo $backFileName |awk -F- '{print $1}'` #20180612170632
        fileType=`echo $backFileName |awk -F- '{print $2}'` #full inc
        if [ "${#fileTime}" != "14" ] ; then
            echo "file $bkFile filename not a mongoBackup.sh\'s standard backup file"
            exit 1
        fi 
        if [ "${fileType}" != "full" -a "${fileType}" != "inc" ] ; then
            echo "file $bkFile filename not a mongoBackup.sh\'s standard backup file"
            exit 1
        fi
        echo "$fileType   $bkFile"
    done
    

    echo -n "Are you sure restore the above file to the database(y/n)[n]: "
    read answer
    if [ "$answer" != "y" ] ; then
        exit 0
    fi
    for bkFile in $backFiles ; do
        backFileName=`echo $bkFile |sed -e "s|.*/||" -e "s|.tar.gz||"`
        echo "${APP_BASE}/install/zkutil.sh get $backupZkNode/$backFileName  2>/dev/null"
        backInfo=`${APP_BASE}/install/zkutil.sh get $backupZkNode/$backFileName  2>/dev/null ` 
        fileTime=`echo $backFileName |awk -F- '{print $1}'` #20180612170632
        fileType=`echo $backFileName |awk -F- '{print $2}'` #full inc
        filePort=`echo $backFileName |awk -F- '{print $3}'` #full inc
        if [ "$backInfo" != "" ] ; then
            echo -e "file $bkFile \nbackinfo: \n `echo "$backInfo" |jq '.' `"
        else
            echo "file $bkFile zknode not exists: $backupZkNode/$backFileName"
        fi 
        
        if [ "$specifyMongoPort" != "true" ] ; then
            mongoPort=$filePort
        fi 
        
        getMongoShardMaster
        mongoHost=$masterNode
 
        dockerTempDir="/var/log/mongodb/$backFileName"
        tempDir="${LOGS_BASE}/mongo/mongos/$backFileName" 
        mkdir -p $tempDir
        tar xf $bkFile -C $tempDir
        cd $tempDir
        if [ "$fileType" = "full" ] ; then
            mongoOpts=" --drop  " #--verbose
            
            echo "`pwd`"
            haveAdminDb=false
            if [ -d "admin" -a -f "admin/system.users.bson" ] ; then
                mv admin ../$backFileName-admin
                haveAdminDb=true
            fi 
            if [ -e "oplog.bson" ] ; then
                mongoOpts="$mongoOpts --oplogReplay "
            fi
            if [ "$specifyMongoPort" != "true" ] ; then #
                if [ -e "oplog.bson" ] ; then
                    mongoPort=$filePort
                else
                    mongoPort=27017
                fi 
            fi
            if [ -e "oplog.bson" ] ; then
                  getMongoShardMaster
            fi 
            if [ "$mongoUser" != "" -a "$mongoPass" != "" ] ; then
                mongoUserOpts=" -u \"$mongoUser\"  -p \"$mongoPass\" --authenticationDatabase admin "
            fi 
            echo "docker exec -i mongo-mongos-$HOSTNAME mongorestore --host $mongoHost --port $mongoPort   $mongoUserOpts   $mongoOpts   $dockerTempDir"
            docker exec -i mongo-mongos-$HOSTNAME mongorestore --host $mongoHost --port $mongoPort   $mongoUserOpts  $mongoOpts  $dockerTempDir
            if [ "$haveAdminDb" = "true" ] ; then
                echo "begin recovery admin ..."
                mv ../$backFileName-admin admin
                echo "docker exec -i mongo-mongos-$HOSTNAME mongorestore --host $mongoHost --port $mongoPort    $mongoUserOpts  $mongoOpts   --batchSize=1  $dockerTempDir"
                docker exec -i mongo-mongos-$HOSTNAME mongorestore --host $mongoHost --port $mongoPort  $mongoUserOpts   $mongoOpts   --batchSize=1 --db admin $dockerTempDir/admin
            fi
        else
            if [ "$specifyMongoPort" != "true" ] ; then #
                mongoPort=$filePort
            fi
            getMongoShardMaster
            mongoOpts="--oplogReplay   --verbose  "
            if [ "$oplogLimit" != "" ] ; then
                mongoOpts="$mongoOpts --oplogLimit '$oplogLimit'" 
            fi 
            if [ "$mongoUser" != "" -a "$mongoPass" != "" ] ; then
                mongoUserOpts=" -u \"$mongoUser\"  -p \"$mongoPass\" --authenticationDatabase admin "
            fi 
            echo "docker exec -i mongo-mongos-$HOSTNAME mongorestore --host $mongoHost --port $mongoPort  $mongoUserOpts  $mongoOpts  $dockerTempDir"
            docker exec -i mongo-mongos-$HOSTNAME mongorestore --host $mongoHost --port $mongoPort  $mongoUserOpts  $mongoOpts     $dockerTempDir
        fi 
        rm -rf $tempDir
    done 
}

dumpbsonToFile()
{
    backFiles="$backFile"
    if [ -d "$backFile" ] ; then
        backFiles=`find ${SHARED_PATH}/backup/mongo/ -name "*.tar.gz"`
    fi 
    for bkFile in $backFiles ; do
        backFileName=`echo $bkFile |sed -e "s|.*/||" -e "s|.tar.gz||"`
        fileTime=`echo $backFileName |awk -F- '{print $1}'` #20180612170632
        fileType=`echo $backFileName |awk -F- '{print $2}'` #full inc
        if [ "${#fileTime}" != "14" ] ; then
            echo "fileTime=$fileTime"
            echo "file $bkFile filename not a mongoBackup.sh\'s standard backup file"
            exit 1
        fi 
        if [ "${fileType}" != "full" -a "${fileType}" != "inc" ] ; then
            echo "file $bkFile filename not a mongoBackup.sh\'s standard backup file"
            exit 1
        fi
        dockerTempDir="/var/log/mongodb/$backFileName"
        tempDir="${LOGS_BASE}/mongo/mongos/$backFileName" 
        mkdir -p $tempDir
        tar xf $bkFile -C $tempDir
        cd $tempDir
        needCopy=false
        if [ "${outputDir}" = "${outputDir//$LOGS_BASE\/mongo\/mongos/}" ] ; then
            destFileDir="$LOGS_BASE/mongo/mongos/$backFileName"
            needCopy=true
        else
            destFileDir="$outputDir/$backFileName"
        fi 
        mkdir -p $destFileDir
        bsonFiles=`find . -name "*.bson"`
        for bsonFile in $bsonFiles ; do
            fileName=`echo $bsonFile|sed -e "s|.*/||"  `
            fileTdir=`echo ${bsonFile:2}|sed -e "s|/$fileName||"`
            fileName=`echo $fileName|sed -e "s|.bson||" `
            fileTdir="$destFileDir/$fileTdir"
            mkdir -p $fileTdir
            echo "docker exec -i mongo-mongos-`hostname` bsondump $dockerTempDir/$bsonFile > $fileTdir/$fileName.json"
            docker exec -i mongo-mongos-`hostname` bsondump $dockerTempDir/$bsonFile > $fileTdir/$fileName.json
        done
        if [ "$needCopy" = "true" ] ; then
            mkdir -p $outputDir
            rm -rf $outputDir/$backFileName
            mv $destFileDir $outputDir/
        fi 
    done
}
    

if [ "$command" = "recovery" ] ; then
    getMongoInfo
    recoveryDataBase
elif [ "$command" = "dumpbson" ] ; then
    getMongoInfo
    dumpbsonToFile 
fi



#--drop  --drop --verbose 27017

# 恢复
#docker exec -ti mongo-mongos-hivenode01 mongorestore --host 172.16.131.136 --port 27117 --authenticationDatabase admin  -u 'sobeyhive' -p '$0bEyHive*2o1Six'   --oplogReplay /dump
# limit
#docker exec -ti mongo-mongos-hivenode01 mongorestore --host 172.16.131.136 --port 27917 --authenticationDatabase admin  -u 'sobeyhive' -p '$0bEyHive*2o1Six' --oplogReplay --oplogLimit "1443024507:1" dump/

