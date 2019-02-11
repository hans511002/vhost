#!/bin/bash 
. /etc/bashrc 
. $APP_BASE/install/funs.sh 
BIN=$(cd $(dirname $0); pwd) 
 
 
printTag()
{
   echo "usetag: <inc|full>  [isshard(true/false)] "
   exit 1
}

if [ "$#" -lt "1" ] ; then 
   printTag
   exit 1 
fi  

mongoBackType=$1
mongoBackupDesc=$2
if [ "$mongoBackType" != "inc" -a  "$mongoBackType" != "full" ] ; then
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
mongoPort=27017
isShardBack=$2

tmpShellFile="/tmp/mongo_${mongoBackType}_back.sh"
for shardHost in $shardHosts ; do
    ((shardId++))
    echo "shardrs$shardId : $shardHost"
    if [ "$mongoBackType" = "inc" -o "$isShardBack" = "true" ] ; then
        mongoPort="27${shardId}17"
    fi 
    shardHost="${shardHost//,/ }"
    fullBacked=false
    for HOST in $shardHost ; do
        hostShell=`ssh $HOST /bin/ls $BIN/mongoBackup.sh`
        if [ "$hostShell" = "" ] ; then
            echo "error: $BIN/mongoBackup.sh not in host $HOST"
            exit 1
        fi 
        echo "#!/bin/bash 
. /etc/bashrc 
. \$APP_BASE/install/funs.sh 
mongoBackupDesc=\"back_with_shardrs${shardId}\"
export mongoBackupDesc
$hostShell ${mongoBackType} ${SHARED_PATH}/backup/mongo $HOST $mongoPort 
">$tmpShellFile
        echo "exec host =$HOST  cat $tmpShellFile"
        cat $tmpShellFile
        chmod +x $tmpShellFile 
        if [ "$HOST" != "`hostname`" ] ; then
            scp -rp $tmpShellFile $HOST:$tmpShellFile
            rm -rf $tmpShellFile
        fi 
        ssh $HOST "$tmpShellFile"
        RES=$?
        ssh $HOST  rm -rf $tmpShellFile
        if [ "$RES" = "0" ] ; then
            if [ "$mongoPort" = "27017" ] ; then
                fullBacked=true
            fi 
            break
        fi 
    done
    if [ "$fullBacked" = "true" ] ; then
        break
    fi 
done
