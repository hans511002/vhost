#!/bin/bash 
# author: zouyg 
# 

. /etc/bashrc
. $APP_BASE/install/funs.sh

_LOCALIP=$1
_LOCALHOSTNAME=$2
_VERSION=$3
_FROM_VERSION=${4:-"0.0.0"}

if [ $# -lt 3 ] ; then 
  echo "usetag: localip localhostname appver [fromver] "
  exit 1
fi

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

if [ "$_LOCALHOSTNAME" = "" ] ; then
_LOCALHOSTNAME=$HOSTNAME
fi 

sqlFiles=`ls $bin/*/*/*.json 2>/dev/null`
if [ "$sqlFiles" = "" ] ; then
 echo "no json files found, rollback skiped."
exit 0
fi

echo "mysql data for $appName initing!"
if [ "${mongo_hosts//$HOSTNAME/}" = "${mongo_hosts}" ] ; then
    zkHost=${mongo_hosts//,/ }
    zkHost=`echo $zkHost | awk '{print $1}' `
    SSHHOST="ssh $zkHost"
    mysqlContainerName=`$SSHHOST docker ps |grep mongo-mongos | grep $zkHost | awk '{print $NF}'`
    if [ "$mysqlContainerName" = "" ] ; then
        echo "mysql not running"
        exit 1
    fi
else
    SSHHOST=""
    mysqlContainerName=`docker ps |grep mongo-mongos | grep $HOSTNAME | awk '{print $NF}'`
    if [ "$mysqlContainerName" = "" ] ; then
        echo "mysql not running"
        exit 1
    fi
fi
echo "mongo ContainerName=$MongoContainerName"


isMongoPasswd=`$SSHHOST cat \$MONGO_HOME/mongo_cluster.conf | grep "isMongoPasswd="|sed -e "s|isMongoPasswd=||"`
mongocmd=
if [ "$isMongoPasswd" = "true" ]; then
    mongoUser=`$SSHHOST cat \$MONGO_HOME/mongo_cluster.conf | grep "mongoUser="|sed -e "s|mongoUser=||"`
    mongoPasswd=`$SSHHOST cat \$MONGO_HOME/mongo_cluster.conf | grep "mongoPasswd="|sed -e "s|mongoPasswd=||"`
    echo "mongocmd=-u '$mongoUser' -p '$mongoPasswd' --authenticationDatabase admin"
    mongocmd="-u '$mongoUser' -p '$mongoPasswd' --authenticationDatabase admin"
fi

echo "upgrade $appName database from $_FROM_VERSION to $_VERSION"
sqlDIR=`ls $bin -F |grep /|grep -v init |awk -F/ '{print $1}' | grep '^[0-9]'|sort -Vr`  # ÄæÐò

needUpdateDir=""
for dir in $sqlDIR ; do
	echo "sql dir $dir"
	gtFrom=`cmpVersion $dir $_FROM_VERSION`
	leTo=`cmpVersion $dir $_VERSION`
	
	echo "$dir $_FROM_VERSION gtFrom=$gtFrom"
	echo "$dir $_VERSION leTo=$leTo"
	if [ "$gtFrom" -eq "1" -a "$leTo" -le "0" ] ; then
		 needUpdateDir="$needUpdateDir  $dir"
	fi
done
echo "needUpdateDir=$needUpdateDir"
for dir in $needUpdateDir ; do
	echo "update database to $dir"
	sqlFiles=`ls   $bin/$dir/rollback/*.js  2>/dev/null`
	
	if [ "$sqlFiles" = "" ] ; then
		 echo "version $dir not exists js file in  $bin/$dir/rollback "
		 continue
	fi
	 
    ssh $mongoHost "mkdir -p ${LOGS_BASE}/mongo/mongos/$dir/rollback"
    for jsFile in $bin/$dir/rollback/*.js ; do 
	    #echo "$SSHHOST docker exec $MongosContainerName mongo  $mongocmd $appName ;TODO;"
        scp $jsFile $mongoHost:${LOGS_BASE}/mongo/mongos/$dir/rollback
        echo " $SSHHOST \"docker exec -i $MongoContainerName mongo $mongocmd $appName < $jsFile\""
        ssh $mongoHost "docker exec -i $MongoContainerName mongo $mongocmd $appName < $jsFile"

    done
done
echo "mongo data for $appName rollback!"
