#! /bin/bash

if [ $# -lt 2 ] ; then 
  echo "usetag:mongo_expand.sh CLUSTER_HOST_LIST EXPAND_HOSTS_LIST"
  exit 1
fi
. /etc/bashrc
. ${APP_BASE}/install/funs.sh

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

CLUSTER_HOST_LIST=$1
CLUSTER_HOST_LIST=" ${CLUSTER_HOST_LIST//,/ } "

EXPAND_HOSTS_LIST=$2
EXPAND_HOSTS_LIST=" ${EXPAND_HOSTS_LIST//,/ } "

mongoVersion=`getAppVer mongo`
if [ "$mongoVersion" = "" ] ; then
    echo "get system env mongo version failed MONGO_HOME=$MONGO_HOME"
    exit 1
fi 
mongoCfg="$MONGO_HOME/mongo_cluster.conf"
if [ ! -f "$mongoCfg" ] ; then
    echo "mongo install config file not exists:$mongoCfg"
fi 

configIplist=`cat $mongoCfg |grep configdb.iplist=| awk -F= '{print $2}'`

mongoUser=`cat $mongoCfg |grep -E "^mongoUser="|awk -F= '{print $2}'`
mongoPass=`cat $mongoCfg |grep -E "^mongoPasswd="|awk -F= '{print $2}'`
if [ "$mongoUser" != "" -a "$mongoPass" != "" ] ; then
    mongoUserOpts=" -u '$mongoUser'  -p '$mongoPass' --authenticationDatabase admin "
fi
shardCount=`cat $mongoCfg |grep shardreplicaset.count=| awk -F= '{print $2}'`
shardCount=`trim "$shardCount"`
consCount=`expr $shardCount + 2`
OLD_HOSTS_LIST=" "
firstOldHost=
for HOST in $CLUSTER_HOST_LIST ; do
    if [ "${EXPAND_HOSTS_LIST// $HOST /}" = "$EXPAND_HOSTS_LIST" ] ; then
        OLD_HOSTS_LIST="$OLD_HOSTS_LIST$HOST "
        if [ "$firstOldHost" = "" ] ; then
            firstOldHost="$HOST"
        fi 
    fi 
done
keyFileUser=`ssh $firstOldHost "ls -l ${DATA_BASE}/mongo"|grep -E "( keyfile)\$" |awk '{printf("%s:%s",$3,$4);}' `
echo "check keyFileUser=$keyFileUser "
if [ "$keyFileUser" != "" ] ; then
    for HOST in $EXPAND_HOSTS_LIST ; do
        echo "ssh $HOST \"scp -rp ${firstOldHost}:${DATA_BASE}/mongo/keyfile ${DATA_BASE}/mongo/\""
        ssh $HOST "scp -rp ${firstOldHost}:${DATA_BASE}/mongo/keyfile ${DATA_BASE}/mongo/"
        echo "ssh $HOST \"chown -R $keyFileUser ${DATA_BASE}/mongo/keyfile \""
        ssh $HOST "chown -R $keyFileUser ${DATA_BASE}/mongo/keyfile "
    done
fi 


nowTime=`date +%Y%m%d%H%M%S`
MONOGO_RUNS_SHELLS=
function mongoExpandCheck()
{
    echo "beging to check mongo cluster ... "
    for HOST in $CLUSTER_HOST_LIST ; do
        mongoCons=`ssh $HOST docker ps -a|grep mongo|awk '{print $NF}'|grep "$HOST" | grep -E "(mongo-mongos-)|(mongo-shardrs)|(mongo-cfg-)" `
        echo "mongoCons=$mongoCons"
        mongoNum=(${mongoCons})
        mongoNum=${#mongoNum[*]}
        if [ "$mongoNum" != "$consCount" ] ; then
            echo "host $HOST mongo containers size not match config file:$mongoCfg"
            exit 1
        fi 
        mongoRuns=`ssh $HOST "ls ${APP_BASE}/install/mongo/mongo-*${mongoVersion}-run.sh "`
        if [ "$MONOGO_RUNS_SHELLS" = "" ] ; then
            MONOGO_RUNS_SHELLS="$mongoRuns"
            echo "MONOGO_RUNS_SHELLS=$MONOGO_RUNS_SHELLS"
        fi 
        mongoRuns=($mongoRuns)
        mongoRuns=${#mongoRuns[*]}
        if [ "$mongoRuns" != "3" ] ; then
            echo "host $HOST mongo containers run shell not exists"
            exit 1
        fi 
    done
}

mongoBackTarFile="${DATA_BASE}/mongo-$nowTime.tar.gz "
function mongoExpandBack()
{
    echo "beging to  expand mongo  back data .... "
    for HOST in $OLD_HOSTS_LIST ; do
        echo "ssh $HOST scp -rp ${APP_BASE}/install/mongo ${APP_BASE}/install/mongo_exp_bak"
        ssh $HOST rm -rf ${APP_BASE}/install/mongo_exp_bak
        ssh $HOST scp -rp ${APP_BASE}/install/mongo ${APP_BASE}/install/mongo_exp_bak
        echo "ssh $HOST \"cd ${DATA_BASE};tar zcf $mongoBackTarFile mongo \""
        ssh $HOST "cd ${DATA_BASE};tar zcf $mongoBackTarFile mongo "
    done
    for HOST in $EXPAND_HOSTS_LIST ; do
        ssh $HOST rm -rf ${APP_BASE}/install/mongo_exp_bak
        ssh $HOST scp -rp ${APP_BASE}/install/mongo ${APP_BASE}/install/mongo_exp_bak    
        ssh $HOST "rm -rf ${DATA_BASE}/mongo/cfgdb/*  ${DATA_BASE}/mongo/hiveshard*/* "
    done 
    echo "back end"
}

getMongoShardMaster()
{
    mongoHost=$1
    mongoPort=$2
    
    echo " get master from $mongoHost $mongoPort" >&2
    
    masterNode=`ssh $mongoHost "echo \"rs.status().members;\" | docker exec -i mongo-mongos-$mongoHost  mongo hivedb --host $mongoHost --port $mongoPort $mongoUserOpts" |grep -B3 "stateStr.*PRIMARY"|grep "name.*$mongoPort"|awk -F'[": ]+' '{print $3}'`
#masterNode=`echo "echo \"rs.status().members;\" | docker exec -i mongo-mongos-$HOSTNAME  mongo hivedb --host $mongoHost --port $mongoPort $mongoUserOpts"|sh|grep -B3 "stateStr.*PRIMARY"|grep "name.*$mongoPort"|awk -F'[": ]+' '{print $3}'`
    if [ "$masterNode" = "" ] ; then
        echo "ssh $mongoHost 'echo \"rs.status().members;\"|docker exec -i mongo-mongos-$HOSTNAME mongo --host $mongoHost --port $mongoPort $mongoUserOpts '" >&2
        echo "masterNode is null "  >&2
        exit 1
    fi
    echo "$masterNode"
}

function mongoExpandConfig()
{
#update run shell mongo-mongos-
echo "beging to expand mongo ... "
echo "#! /bin/bash
. /etc/bashrc
. ${APP_BASE}/install/funs.sh
mongosShell=\`ls ${APP_BASE}/install/mongo/mongo-mongos-${mongoVersion}-run.sh\`
mongoCfgShell=\`ls ${APP_BASE}/install/mongo/mongo-cfgdb-${mongoVersion}-run.sh\`
mongoShardShell=\`ls ${APP_BASE}/install/mongo/mongo-shardrs-${mongoVersion}-run.sh\`

sed -i -e \"s|hiveconfigdb/.*27917 |hiveconfigdb/$configIplist |\" \$mongosShell
if [ \"$keyFileUser\" != \"\" ] ; then
    keyFile=\`cat \$mongosShell | grep \"docker run \"|grep \"\\--keyFile\" |awk -F\"--keyFile\" '{print \$2}'\`
    echo \"keyFile=\$keyFile\"
    if [ \"\$keyFile\" = \"\" ] ; then
        echo "add --keyFile /data/keyfile/mongodb-keyfile  to \$mongosShell "
        sed -i -e \"s|\(docker run .*\)|\\\1 --keyFile /data/keyfile/mongodb-keyfile |\" \$mongosShell
    fi
    keyFile=\`cat \$mongoCfgShell | grep \"docker run \"|grep \"\\--keyFile\" |awk -F\"--keyFile\" '{print \$2}'\`
    echo \"keyFile=\$keyFile\"
    if [ \"\$keyFile\" = \"\" ] ; then
        echo "add --keyFile /data/keyfile/mongodb-keyfile  to \$mongoCfgShell "
        sed -i -e \"s|\(docker run .*\)|\\\1 --keyFile /data/keyfile/mongodb-keyfile |\" \$mongoCfgShell
    fi 
    keyFile=\`cat \$mongoShardShell | grep \"docker run \"|grep \"\\--keyFile\" |awk -F\"--keyFile\" '{print \$2}'\`
    echo \"keyFile=\$keyFile\"
    if [ \"\$keyFile\" = \"\" ] ; then
        echo "add --keyFile /data/keyfile/mongodb-keyfile  to \$mongoShardShell "
        sed -i -e \"s|\(docker run .*\)|\\\1 --keyFile /data/keyfile/mongodb-keyfile |\" \$mongoShardShell
    fi 
    
    # -v  :27017 -v ${DATA_BASE}/mongo/keyfile:/data/keyfile 
    keyFile=\`cat \$mongosShell | grep \"docker run \"|grep \"keyfile:/data/keyfile\" \`
    if [ \"\$keyFile\" = \"\" ] ; then
        echo "add -v ${DATA_BASE}/mongo/keyfile:/data/keyfile  to \$mongosShell "
        sed -i -e \"s|\(:27017\) |\\\1 -v ${DATA_BASE}/mongo/keyfile:/data/keyfile |\" \$mongosShell
    fi
    keyFile=\`cat \$mongoCfgShell | grep \"docker run \"|grep \"keyfile:/data/keyfile\" \`
    if [ \"\$keyFile\" = \"\" ] ; then
        echo "add -v ${DATA_BASE}/mongo/keyfile:/data/keyfile  to \$mongoCfgShell "
        sed -i -e \"s|\(:27017\) |\\\1 -v ${DATA_BASE}/mongo/keyfile:/data/keyfile |\" \$mongoCfgShell
    fi    
    keyFile=\`cat \$mongoShardShell | grep \"docker run \"|grep \"keyfile:/data/keyfile\" \`
    if [ \"\$keyFile\" = \"\" ] ; then
        echo "add -v ${DATA_BASE}/mongo/keyfile:/data/keyfile  to \$mongoShardShell "
        sed -i -e \"s|\(:27017\) |\\\1 -v ${DATA_BASE}/mongo/keyfile:/data/keyfile |\" \$mongoShardShell
    fi    
fi 

mongoCons=\`docker ps -a|grep \"mongo-\" |awk '{print \$NF}'|grep \"\$HOSTNAME\" | grep -E \"(mongo-mongos-)|(mongo-shardrs)|(mongo-cfg-)\" \`
mongoCons=\`echo \$mongoCons\`
echo \"docker rm -f \$mongoCons\"
docker rm -f \$mongoCons

echo \"\$mongosShell\"
\$mongosShell
echo \"\$mongoCfgShell\"
\$mongoCfgShell
echo \"\$mongoShardShell\"
\$mongoShardShell
 
">/tmp/mongoexp.sh
chmod +x /tmp/mongoexp.sh
echo "beging to process mongo run shell "
    for HOST in $CLUSTER_HOST_LIST ; do
        echo "scp /tmp/mongoexp.sh $HOST:/tmp/mongoexp.sh"
        scp /tmp/mongoexp.sh $HOST:/tmp/mongoexp.sh
        echo "ssh $HOST /tmp/mongoexp.sh"
        ssh $HOST /tmp/mongoexp.sh
    done
#--port 27017 --logpath /var/log/mongodb/mongodb.log --keyFile /data/keyfile/mongodb-keyfile


## rerun old host
#echo "beging to rerun old mongo "
#for HOST in $OLD_HOSTS_LIST ; do
#    mongoCons=`ssh $HOST docker ps -a|grep mongo|awk '{print $NF}'|grep "$HOST" | grep -E "(mongo-mongos-)|(mongo-shardrs)|(mongo-cfg-)" `
#    mongoCons=`echo $mongoCons`
#    echo "ssh $HOST \"docker rm -f $mongoCons\""
#    ssh $HOST "docker rm -f $mongoCons"
#    for mongoRun in $MONOGO_RUNS_SHELLS ; do
#        echo "ssh $HOST $mongoRun "
#        ssh $HOST $mongoRun 
#    done
#    echo "$HOST">>/tmp/mongoexp
#done

#for HOST in $EXPAND_HOSTS_LIST ; do
#    for mongoRun in $MONOGO_RUNS_SHELLS ; do
#        ssh $HOST $mongoRun
#    done 
#done

echo "sleep 10s wait mongo start"
sleep 10
echo "beging to check cfgdb master "
checkGetCount=0
while [ "$checkGetCount" -lt "5" ] ; do 
    for HOST in $OLD_HOSTS_LIST ; do
        masterNode=`getMongoShardMaster $HOST 27917`
        if [ "$masterNode" != "" ] ; then
            break
        fi
    done 
    if [ "$masterNode" != "" ] ; then
        break
    fi 
    sleep 10
    ((checkGetCount++))
done
if [ "$masterNode" = "" ] ; then
    echo "cfgdb master is null"
    while [ true ] ; do 
        if [ -f /tmp/mongoexp.sh ] ; then
            echo "wait del /tmp/mongoexp.sh "
           sleep 2
        else
            break
        fi 
    done
    exit 1
fi 
echo "mongo cfgdb masterNode=$masterNode"

# cfg master rs.add

cfgJsStr=""
shardJsStr=()
for HOST in $EXPAND_HOSTS_LIST ; do
    cfgJsStr="${cfgJsStr}
print('rs.add(\\\"$HOST:27917\\\");');
rs.add(\\\"$HOST:27917\\\");"
    shardRsId=1
    while [ "$shardRsId" -le "$shardCount" ] ; do 
        mongoShardPort="27${shardRsId}17"
        shardJsStr[$shardRsId]="${shardJsStr[$shardRsId]}
print('rs.add(\\\"$HOST:$mongoShardPort\\\");');
rs.add(\\\"$HOST:$mongoShardPort\\\");"
        ((shardRsId++))
    done
done

echo "#! /bin/bash
. /etc/bashrc
. ${APP_BASE}/install/funs.sh
echo \"print('begin===> mongo_exp_cfg.js');
$cfgJsStr
print('end===> mongo_exp_cfg.js');
\" > /tmp/mongo_exp_cfg.js

cat  /tmp/mongo_exp_cfg.js 
cat  /tmp/mongo_exp_cfg.js  | docker exec -i  mongo-mongos-$masterNode  mongo admin --host $masterNode --port 27917 $mongoUserOpts

"> /tmp/mongoexp.sh

chmod +x /tmp/mongoexp.sh

echo "scp /tmp/mongoexp.sh $masterNode:/tmp/mongoexp.sh"
scp /tmp/mongoexp.sh $masterNode:/tmp/mongoexp.sh
echo "ssh $masterNode /tmp/mongoexp.sh"
cat /tmp/mongoexp.sh

ssh $masterNode /tmp/mongoexp.sh
if [ "$?" != "0" ] ; then
   exit 1
fi 

# shard master rs.add
shardRsId=1
while [ "$shardRsId" -le "$shardCount" ] ; do 
    echo "beging to check shardrs$shardRsId master "
    checkGetCount=0
    mongoShardPort="27${shardRsId}17"
    while [ "$checkGetCount" -lt "5" ] ; do 
        for HOST in $OLD_HOSTS_LIST ; do
            masterNode=`getMongoShardMaster $HOST ${mongoShardPort}`
            if [ "$masterNode" != "" ] ; then
                break
            fi
        done
        if [ "$masterNode" != "" ] ; then
            break
        fi 
        sleep 5
        ((checkGetCount++))
    done
    if [ "$masterNode" = "" ] ; then
        echo "shard master is null"
        exit 1
    fi
    
    echo "mongo shardrs$shardRsId masterNode=$masterNode"

    echo "#! /bin/bash
. /etc/bashrc
. ${APP_BASE}/install/funs.sh

echo \"print('begin===> mongo_exp_shard${shardRsId}.js');
${shardJsStr[$shardRsId]}
print('end===> mongo_exp_shard${shardRsId}.js');
\" > /tmp/mongo_exp_shard$shardRsId.js

cat  /tmp/mongo_exp_shard$shardRsId.js 
cat  /tmp/mongo_exp_shard$shardRsId.js  | docker exec -i  mongo-mongos-$masterNode  mongo admin --host $masterNode --port $mongoShardPort $mongoUserOpts

#rm -rf /tmp/mongo_exp_cfg.js

"> /tmp/mongoexp.sh
    
    chmod +x /tmp/mongoexp.sh
    echo "scp /tmp/mongoexp.sh $masterNode:/tmp/mongoexp.sh"
    scp /tmp/mongoexp.sh $masterNode:/tmp/mongoexp.sh    
    echo "ssh $masterNode /tmp/mongoexp.sh"
    cat /tmp/mongoexp.sh
    ssh $masterNode /tmp/mongoexp.sh
    if [ "$?" != "0" ] ; then
       exit 1
    fi 
    ((shardRsId++))
    
done

echo "$MONGO_HOME/sbin/check_mongo_cluster_status.sh"
$MONGO_HOME/sbin/check_mongo_cluster_status.sh 
#rm -rf /tmp/mongoexp.sh
}

function mongoExpandRollBack()
{
    echo "expand mongo failed, beging to rollback .... "
    for HOST in $EXPAND_HOSTS_LIST ; do
        echo "ssh $HOST \"scp -rp ${APP_BASE}/install/mongo_exp_bak/* ${APP_BASE}/install/mongo/ \""
        ssh $HOST "scp -rp ${APP_BASE}/install/mongo_exp_bak/* ${APP_BASE}/install/mongo/ "
        echo "ssh $HOST \"rm -rf ${APP_BASE}/install/mongo_exp_bak\""
        ssh $HOST "rm -rf ${APP_BASE}/install/mongo_exp_bak"
        mongoCons=`ssh $HOST docker ps -a|grep mongo|awk '{print $NF}'|grep "$HOST" | grep -E "(mongo-mongos-)|(mongo-shardrs)|(mongo-cfg-)" `
        mongoCons=`echo $mongoCons`
        echo "ssh $HOST \"docker rm -f $mongoCons\""
        ssh $HOST "docker rm -f $mongoCons"
    done
    for HOST in $OLD_HOSTS_LIST ; do
        echo "ssh $HOST \"scp -rp ${APP_BASE}/install/mongo_exp_bak/* ${APP_BASE}/install/mongo/ \""
        ssh $HOST "scp -rp ${APP_BASE}/install/mongo_exp_bak/* ${APP_BASE}/install/mongo/ "
        echo "ssh $HOST \"rm -rf ${APP_BASE}/install/mongo_exp_bak\""
        ssh $HOST "rm -rf ${APP_BASE}/install/mongo_exp_bak"
        mongoCons=`ssh $HOST docker ps -a|grep mongo|awk '{print $NF}'|grep "$HOST" | grep -E "(mongo-mongos-)|(mongo-shardrs)|(mongo-cfg-)" `
        mongoCons=`echo $mongoCons`
        echo "ssh $HOST \"cd ${DATA_BASE};rm -rf mongo/*; tar xf $mongoBackTarFile \""
        ssh $HOST "cd ${DATA_BASE};rm -rf mongo/*; tar xf $mongoBackTarFile "
        echo "ssh $HOST \"docker rm -f $mongoCons\""
        ssh $HOST "docker rm -f $mongoCons"
        for mongoRun in $MONOGO_RUNS_SHELLS ; do
            echo "ssh $HOST $mongoRun"
            ssh $HOST $mongoRun
        done 
    done
    echo "rollback end "
}

check=`mongoExpandCheck 1>&2`
if [ "$?" != "0" ] ; then
   exit 1
fi
`mongoExpandBack 1>&2`
if [ "$?" != "0" ] ; then
   exit 1
fi
expcfg=`mongoExpandConfig 1>&2`
if [ "$?" != "0" ] ; then
   mongoExpandRollBack
   exit 1
fi 

