#!/bin/bash 
. /etc/bashrc 
. $APP_BASE/install/funs.sh 
BIN=$(cd $(dirname $0); pwd) 
 
 
printTag()
{
   echo "usetag: <shell>  [shell params]
     shell:
        mongoBackup.sh <inc|full|list|clean>  [backupDir:${SHARED_PATH}/backup/mongo] [mongoHost] [mongoPort:27117] [mongoUser] [mongoPass]
        mongoRecovery.sh <recovery> <backFile|backupDir> [oplogLimit(ts:0)] [mongoHost] [mongoPort] [mongoUser] [mongoPass]
   "
   exit 1
}

if [ "$#" -lt "1" ] ; then 
   printTag
   exit 1 
fi  

mongoShell=$1
shift

if [ ! -f "$mongoShell" ] ; then
   echo "shell file not exists: $mongoShell"
   printTag
   exit 1
fi 

if [ "$MONGO_HOME" = "" ] ; then
    echo "not install mongo in this host"
    exit 1
fi 

if [ ! -f "$MONGO_HOME/mongo_cluster.conf" ] ; then
   echo "mongo install config file not exists on this host:$MONGO_HOME/mongo_cluster.conf"
    exit 1
fi 
shardreplicasetCount=`cat $MONGO_HOME/mongo_cluster.conf | grep -E "^shardreplicaset.count=" | sed -e "s|shardreplicaset.count=\([0-9]\)|\1|" `
shardreplicasetIpmap=`cat $MONGO_HOME/mongo_cluster.conf | grep -E "^shardreplicaset.ipmap=" | sed -e "s|shardreplicaset.ipmap=||" `
shardHosts="${shardreplicasetIpmap//;/ }"
shardId=0

for shardHost in $shardHosts ; do
    ((shardId++))
    echo "shardrs$shardId : $shardHost"
    shardHost="${shardHost//,/ }"
    for HOST in $shardHost ; do
        hostShell=`ssh $HOST /bin/ls $mongoShell`
        if [ "$hostShell" = "" ] ; then
            hostShell=`ssh $HOST /bin/ls $BIN/$mongoShell`
        fi
        if [ "$hostShell" = "" ] ; then
            echo "mongoShell: $mongoShell not in host $HOST"
            exit 1
        fi 
        ssh $HOST $hostShell "$@"
        if [ "$?" = "0" ] ; then
            break
        fi 
    done
    mongoBackupDesc=""
    export mongoBackupDesc
    
done






