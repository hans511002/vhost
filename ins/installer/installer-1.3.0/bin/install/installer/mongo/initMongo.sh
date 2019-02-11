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

jsonFiles=`ls $bin/*/*/*.json 2>/dev/null`
jsFiles=`ls $bin/*/*/*.js 2>/dev/null`
if [ "$jsonFiles" = "" -a "$jsFiles" = "" ] ; then
	echo "no json files found, data initialization skiped."
    exit 0
fi

echo "Mongo data for $appName initing!"
MongosContainerName="mongo-mongos-$_LOCALHOSTNAME" 
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
    SSHHOST="sh $HOSTNAME"
    mysqlContainerName=`docker ps |grep mongo-mongos | grep $HOSTNAME | awk '{print $NF}'`
    if [ "$mysqlContainerName" = "" ] ; then
        echo "mysql not running"
        exit 1
    fi
fi
 echo "Mongos ContainerName=$MongosContainerName"
 
isMongoPasswd=`$SSHHOST cat \$MONGO_HOME/mongo_cluster.conf | grep "isMongoPasswd="|sed -e "s|isMongoPasswd=||"`
mongocmd=
if [ "$isMongoPasswd" = "true" ]; then
    mongoUser=`$SSHHOST cat \$MONGO_HOME/mongo_cluster.conf | grep "mongoUser="|sed -e "s|mongoUser=||"`
    mongoPasswd=`$SSHHOST cat \$MONGO_HOME/mongo_cluster.conf | grep "mongoPasswd="|sed -e "s|mongoPasswd=||"`
    echo "mongocmd=-u '$mongoUser' -p '$mongoPasswd' --authenticationDatabase admin"
    mongocmd="-u '$mongoUser' -p '$mongoPasswd' --authenticationDatabase admin"
fi

 echo "upgrade $appName database from $_FROM_VERSION to $_VERSION"
 sqlDIR=`ls $bin -F |grep /|grep -v init |awk -F/ '{print $1}' | grep '^[0-9]'|sort -V`
  MVER=`echo $_FROM_VERSION |awk -F. '{print $1}'`
  SVER=`echo $_FROM_VERSION |awk -F. '{print $2}'`
  EVER=`echo $_FROM_VERSION |awk -F. '{print $3}'`
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
		sqlFiles=`ls   $bin/$dir/upgrade/*.js  2>/dev/null`
		
		if [ "$sqlFiles" = "" ] ; then
			 echo "version $dir not exists js file in  $bin/$dir/upgrade "
			 continue
		fi

		$SSHHOST mkdir -p ${LOGS_BASE}/mongo/mongos/$dir/upgrade
        if [ "$SSHHOST" != "" ] ; then
        	scp -f $bin/$dir/upgrade/*.js ${SSHHOST//ssh /}:${LOGS_BASE}/mongo/mongos/$dir/upgrade
        else
            cp -f $bin/$dir/upgrade/*.js ${LOGS_BASE}/mongo/mongos/$dir/upgrade
        fi
		for jsFile in $bin/$dir/upgrade/*.js ; do 
		   args="docker exec -i $MongosContainerName mongo  $mongocmd $appName < $jsFile"
		   echo "$SSHHOST ${args}"
		    $SSHHOST "  docker exec -i $MongosContainerName mongo  $mongocmd $appName < $jsFile "
		done
done   
  
for dir in $needUpdateDir ; do
		echo "update database to $dir"
		sqlFiles=`ls   $bin/$dir/upgrade/*.json  2>/dev/null`
		
		if [ "$sqlFiles" = "" ] ; then
			 echo "version $dir not exists json file in  $bin/$dir/upgrade "
			 continue
		fi
		#1.拷贝json文件到mongos的 docker内的日志目录下
		#2.文件名必须与mongo的collection一致
		#3.导入的默认操作是覆盖方式
		$SSHHOST mkdir -p ${LOGS_BASE}/mongo/mongos/$dir/upgrade
		if [ "$SSHHOST" != "" ] ; then
        	scp -f $bin/$dir/upgrade/*.json ${SSHHOST//ssh /}:${LOGS_BASE}/mongo/mongos/$dir/upgrade
        else
            cp -f $bin/$dir/upgrade/*.json ${LOGS_BASE}/mongo/mongos/$dir/upgrade
        fi

		for jsonFile in $bin/$dir/upgrade/*.json ; do 
		   args="docker exec $MongosContainerName mongoimport  $mongocmd -d $appName --type json --upsert --file \"/var/log/mongodb/${dir}/upgrade/${jsonFile##*/}\""
		   echo ${args}
		   $SSHHOST  "${args}"
		done
done
echo "Mongo data for $appName Installed!"
