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

sqlFiles=`ls $bin/*/*/*.sql 2>/dev/null`
if [ "$sqlFiles" = "" ] ; then
 echo "no SQL files found,data initialization skiped."
exit 0
fi

echo "mysql data for  $appName  initing!"

if [ "${mysql_hosts//$HOSTNAME/}" = "${mysql_hosts}" ] ; then
    zkHost=${mysql_hosts//,/ }
    zkHost=`echo $zkHost | awk '{print $1}' `
    SSHHOST="ssh $zkHost"
    mysqlContainerName=`$SSHHOST docker ps |grep mysql | grep $zkHost | awk '{print $NF}'`
    if [ "$mysqlContainerName" = "" ] ; then
        echo "mysql not running"
        exit 1
    fi
else
    SSHHOST=""
    mysqlContainerName=`docker ps |grep mysql | grep $HOSTNAME | awk '{print $NF}'`
    if [ "$mysqlContainerName" = "" ] ; then
        echo "mysql not running"
        exit 1
    fi
fi
 

echo "msyql ContainerName=$mysqlContainerName"
 
 echo "upgrade hivecore database from $_FROM_VERSION to $_VERSION"
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
			sqlFiles=`ls   $bin/$dir/upgrade/*.sql  2>/dev/null`
			
			if [ "$sqlFiles" = "" ] ; then
				 echo "version $dir not exists sql file in  $bin/$dir/upgrade "
				 continue
			fi
			for sqlFile in $bin/$dir/upgrade/*.sql ; do 
			   echo " cat $sqlFile  | $SSHHOST docker exec -i $mysqlContainerName mysql   "
			   cat $sqlFile  | $SSHHOST docker exec -i $mysqlContainerName mysql
			done
	done
echo "mysql data for  $appName  Installed!"
