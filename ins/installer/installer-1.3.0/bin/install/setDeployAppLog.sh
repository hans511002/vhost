#!/bin/bash
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ "$INSTALLER_HOME" = "" -o "${installer_hosts}" = "" ] ; then
    echo "not install deploy app : installer"
    exit 1
fi
if [ "$USER" != "root" ] ; then
    echo "must run in root user"
    exit 1
fi

logOutType=$1
if [  "$logOutType" = "" -o "$logOutType" = "-h" ] ; then
    echo "exp1: db dburl=jdbc:mysql://172.16.131.136:3307/paaslog?autoReconnect=true dbuser=sdba dbpass=sdba dbreserved=3 dbpartition=2 "
    echo "exp2: file fileurl=${LOGS_BASE}/installer/applogs"
    echo "exp3: es esurl=172.16.131.136:17100,172.16.131.135:17100,172.16.131.141:17100/eagles"
    echo "exp4: kafka kafkaurl=172.16.131.136:2181,172.16.131.135:2181,172.16.131.141:2181/"
    echo "exp5:db,es dburl=jdbc:mysql://172.16.131.136:3307/paaslog?autoReconnect=true dbuser=sdba dbpass=sdba dbreserved=5 dbpartition=2 esurl=172.16.131.136:17100,172.16.131.135:17100,172.16.131.141:17100/eagles"
    exit 0
fi

checkOutType(){
type=$1
if [ "$type" = "$logOutType" ] ; then
   echo "true"
elif [ "${logOutType//,$type/}" != "$logOutType" -o  "${logOutType//$type,/}" != "$logOutType" ]; then
   echo "true"
else
   echo "false"
fi
}

if [ "`checkOutType file`" != "true" -a "`checkOutType es`" != "true" -a "`checkOutType db`" != "true" -a "`checkOutType kafka`" != "true"  ]; then
echo "only support output logs to file,es,db,kafka "
exit 1
fi
. ${APP_BASE}/install/funs.sh

ZKBaseNode=`getDeployZkNode`
deployGobalConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode`
deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.type"]; "'$logOutType'")'`

setFlag=false

deployGobalConfig=`echo "$deployGobalConfig" | jq  'del(."deployactor.metrics.output.file.url") | del(."deployactor.metrics.output.es.url") | del(."deployactor.metrics.output.kafka.url")| del(."deployactor.metrics.output.kafka.partition") '`
deployGobalConfig=`echo "$deployGobalConfig" | jq  'del(."deployactor.metrics.output.db.url") | del(."deployactor.metrics.output.db.user") | del(."deployactor.metrics.output.db.password") | del(."deployactor.metrics.output.db.partition") | del(."deployactor.metrics.output.db.reserved") '`

echo "$deployGobalConfig" |grep metrics|grep output.type

if [ "`checkOutType file`" = "true" ]; then
    echo "logOutType[$logOutType] include file"
    deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.file.url"]; "")'`
    for par in $@ ; do
        if [ "${par:0:8}" = "fileurl=" ] ; then
            url="${par:8}"
            deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.file.url"]; "'$url'")'`
            break
        fi
    done
    setFlag=true
    echo "$deployGobalConfig" |grep metrics|grep output.file
fi
if [ "`checkOutType es`" = "true" ]; then
    echo "logOutType[$logOutType] include es" 
    #172.16.131.136:17100,172.16.131.135:17100,172.16.131.141:17100/eagles
    if [ "$eagleslog_hosts" != "" ] ; then
        esUrl="${eagleslog_hosts//,/:18100,}:18100/eagles"
    else
        esUrl="${eagles_hosts//,/:17100,}:17100/eagles"
    fi
    deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.es.url"]; "'$esUrl'")'`
    for par in $@ ; do
        if [ "${par:0:6}" = "esurl=" ] ; then
            url="${par:6}"
            deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.es.url"]; "'$url'")'`
            break
        fi
    done
    setFlag=true
    echo "$deployGobalConfig" |grep metrics|grep output.es
fi
if [ "`checkOutType kafka`" = "true" ]; then
    echo "logOutType[$logOutType] include kafka"
    deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.kafka.url"]; "'$ZOOKEEPER_URL'")'`
    for par in $@ ; do
        if [ "${par:0:9}" = "kafkaurl=" ] ; then
            url="${par:9}"
            deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.kafka.url"]; "'$url'")'`
            break
        fi
    done
    setFlag=true 
    echo "$deployGobalConfig" |grep metrics|grep output.kafka
fi
if [ "`checkOutType db`" = "true" ]; then
    echo "logOutType[$logOutType] include db"
    deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.url"]; "jdbc:mysql://'$NEBULA_VIP':3307/paaslog?autoReconnect=true")'`
    deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.user"]; "sdba")'`
    deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.password"]; "sdba")'`
    deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.partition"]; "2")'`
    deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.reserved"]; "5")'`
    for par in $@ ; do
        # dbuser=sdba dbpass=sdba dbreserved=3 dbpartition=2
        if [ "${par:0:6}" = "dburl=" ] ; then
            url="${par:6}"
            deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.url"]; "'$url'")'`
        elif [ "${par:0:7}" = "dbuser=" ] ; then
            url="${par:7}"
            deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.user"]; "'$url'")'`
        elif [ "${par:0:11}" = "dbpassword=" ] ; then
            url="${par:11}"
            deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.password"]; "'$url'")'`
        elif [ "${par:0:12}" = "dbpartition=" ] ; then
            url="${par:12}"
            deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.partition"]; "'$url'")'`
        elif [ "${par:0:11}" = "dbreserved=" ] ; then
            url="${par:11}"
            deployGobalConfig=`echo "$deployGobalConfig" | jq  'setpath(["deployactor.metrics.output.db.reserved"]; "'$url'")'`
        fi
    done
    setFlag=true
    echo "$deployGobalConfig" |grep metrics|grep output.db

fi

dbUrl=`echo "$deployGobalConfig" | jq '."deployactor.metrics.output.db.url"'|sed -e 's/"//g'`
dbUser=`echo "$deployGobalConfig" | jq '."deployactor.metrics.output.db.user"'|sed -e 's/"//g'`
dbPassword=`echo "$deployGobalConfig" | jq '."deployactor.metrics.output.db.password"' |sed -e 's/"//g'`

MYSQL=`which mysql 2>/dev/null`

if [ "$MYSQL" = "" ] ; then
    echo "not install mysql client,install mysql client"
    yum install -y mariadb
fi #
mysqlHost=`echo "${dbUrl}" | sed -e "s|jdbc:mysql://||" -e "s|/.*||"  `
mysqlPort=`echo "${mysqlHost}" | sed -e "s|.*:||"    `
mysqlHost=`echo "${mysqlHost}" | sed -e "s|:.*||"    `
mysqlDbName=`echo "${dbUrl//*\//}" |sed -e "s|?.*||"`

echo "test connection:mysql -h $mysqlHost -P $mysqlPort -u $dbUser -p$dbPassword  -e 'select 1' "
mysql -h $mysqlHost -P $mysqlPort -u $dbUser -p$dbPassword  -e 'select 1'
res=$?
if [ "$res" != "0" ] ; then
    echo "db config error:not login to db"
    exit 1
fi
echo "test db:mysql -h $mysqlHost -P $mysqlPort -u $dbUser -p$dbPassword $mysqlDbName -e 'select 1' "
mysql -h $mysqlHost -P $mysqlPort -u $dbUser -p$dbPassword $mysqlDbName -e 'select 1' 2>/dev/null
res=$?
if [ "$res" != "0" ] ; then # database not exists
    sqlFile=`mktemp /tmp/metrics.db.XXXXXX.sql`
    echo "CREATE DATABASE IF NOT EXISTS $mysqlDbName CHARSET utf8 ">$sqlFile
    echo "mysql -h $mysqlHost -P $mysqlPort -u $dbUser -p$dbPassword < $sqlFile "
    mysql -h $mysqlHost -P $mysqlPort -u $dbUser -p$dbPassword < $sqlFile 
    rm -rf $sqlFile
fi


if [ "$setFlag" = "true" ] ; then
    echo "update set to zk"
    tmpFile=`mktemp /tmp/metrics.XXXXXX`
    echo "$deployGobalConfig" >$tmpFile
    deployGobalConfig=`$INSTALLER_HOME/sbin/installer zkctl -c set -p $ZKBaseNode -f $tmpFile`
    res=$?
    rm -rf $tmpFile
    if [ "$res" = "0" ] ; then
        echo "set log output to $logOutType success"
        cmd.sh service deploy restart
    else
        echo "set log output failed"
    fi
    exit $res
else
    echo "not set log output"
    exit 1
fi
#
#deployactor.metrics.output.db.url=jdbc:mysql://172.16.131.136:3307/paaslog?autoReconnect=true
#deployactor.metrics.output.db.user=sdba
#deployactor.metrics.output.db.password=sdba
#deployactor.metrics.output.db.partition=2
#deployactor.metrics.output.db.reserved=2
