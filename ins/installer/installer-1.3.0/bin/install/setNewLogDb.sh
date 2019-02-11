#!/bin/bash
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
cd $BIN
if [ "$INSTALLER_HOME" = "" -o "${installer_hosts}" = "" ] ; then
    echo "not install deploy app : installer"
    exit 1
fi
if [ "$USER" != "root" ] ; then
    echo "must run in root user : setNewLogDb.sh true"
    exit 1
fi

if [ "$1" != "true" ] ; then
    echo "Must confirm the use new log db
    setNewLogDb.sh true [true|fasle|\"\":set all app autoRestart flag] [paaslogdbHost:mysql_hosts]"
    exit 1
fi

stopAllAppAutoRestart=$2
paaslogdbHost=$3

if [ "$APP_BASE" = "" ] ; then
APP_BASE=/app
fi
. ${APP_BASE}/install/funs.sh

if [ "$stopAllAppAutoRestart" = "true" -o "$stopAllAppAutoRestart" = "false" ] ; then
    echo "$BIN/setAppAutoRestart.sh $stopAllAppAutoRestart "
    $BIN/setAppAutoRestart.sh $stopAllAppAutoRestart
    if [ "$?" != "0" ] ; then
        echo "$BIN/setAppAutoRestart.sh $stopAllAppAutoRestart : set failed"
        exit 1
    fi
fi

ZKBaseNode=`getDeployZkNode`
deployMasterInfo=`curl http://$NEBULA_VIP:64001/deploy/get/master 2>/dev/null`
deployMasterHostIp=`echo "$deployMasterInfo"|jq '.result.hostIp'|sed -e "s|\"||g"`
deployMasterHostName=`echo "$deployMasterInfo"|jq '.result.hostName'|sed -e "s|\"||g"`

if [ "$deployMasterHostName" != "`hostname`" ] ; then
   ssh $deployMasterHostName "$BIN/setNewLogDb.sh true '$stopAllAppAutoRestart' '$paaslogdbHost'"
   exit $?
fi 

deployGobalConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/gobal`
APP_SRC=`echo "$deployGobalConfig" | jq  '.APP_SRC' `
APP_SRC=${APP_SRC//\"/}
echo "APP_SRC=$APP_SRC"
srcDbApp="mysqlcopy"
paasLogDbApp="paaslogdb"
paasLogAppDir="$APP_SRC/$paasLogDbApp"
if [ "$2" = "true" ] ; then
    rm -rf $paasLogAppDir
fi

if [ ! -d "$paasLogAppDir" ] ; then
    echo "copyDb.sh $paasLogDbApp"
    copyDb.sh $paasLogDbApp
    if [ "$?" != "0" ] ; then
       echo "failed: copyDb.sh $paasLogDbApp"
       exit 1
    fi 
else
    echo "$INSTALLER_HOME/sbin/installer zkctl -c imp -p $paasLogDbApp"
    $INSTALLER_HOME/sbin/installer zkctl -c imp -p $paasLogDbApp
fi

convertJsonArrayToString(){
json=$1
json="${json//[/}"
json="${json//]/}"
json="${json//\"/}"
json=`echo $json`
json="${json// /}"
echo "$json"
}


assertPort(){
    lport="$1"
    mysqlHost="$2"
    expPort="$3"
    while [ true ] ;  do
        if [ "${expPort}" != "${expPort//,$lport,/}" ] ; then
            lport=`expr $lport + 1`
            continue
        fi
        findPort=false
        for dbHost in ${mysqlHost//,/ } ; do
            ssh $dbHost netstat -ntl|awk '{print $4}'|grep -E ":$lport\$" >/dev/null
            if [ "$?" = "0" ] ; then
                echo "port $lport exist LISTEN on $dbHost" >&2
                findPort=true
                break
            fi
        done
        if [ "$findPort" = "true" ] ; then
            lport=`expr $lport + 1`
        else
            echo "$lport"
            break
        fi
    done
}

paasLogDbHaPort=3308
paasLogDbPort=3309
paasLogIstPort=3234
paasLogSstPort=3235
paasLogRepPort=3236
paasLogXinetPort=49991

echo "get paasLog db port "
paaslogConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/app/$paasLogDbApp  2>/dev/null `
if [ "$paaslogConfig" = "" ] ; then
    echo "not have $paasLogDbApp config"
    exit 1
fi
passLogHost=`echo "$paaslogConfig" | jq  '.installHost' `
passLogHost=`convertJsonArrayToString "$passLogHost"`
echo "passLogHost=$passLogHost"

paaslogConfs=`echo "$paaslogConfig" | jq  '.app.config."${APP_HOME}/conf/'$paasLogDbApp'-install.conf"' `
echo "old paaslogConfs=$paaslogConfs"
#paaslogConfs="defaultPort=3309\ngaleraPort=4567\ngaleraISTPort=4568\ngaleraSSTPort=4449\ndbXinetPort=49991\n"
paaslogConfs=`echo -e "$paaslogConfs"`
paaslogConfs=`echo $paaslogConfs`
for item in ${paaslogConfs//\"/} ; do
    if [ "$item" != "${item//defaultPort=/}" ] ; then
        paasLogDbPort=`echo "$item" |sed -e 's|defaultPort=||'`
    elif [ "$item" != "${item//galeraPort=/}" ] ; then
        paasLogRepPort=`echo "$item" |sed -e 's|galeraPort=||'`
    elif [ "$item" != "${item//galeraISTPort=/}" ] ; then
        paasLogIstPort=`echo "$item" |sed -e 's|galeraISTPort=||'`
    elif [ "$item" != "${item//galeraSSTPort=/}" ] ; then
        paasLogSstPort=`echo "$item" |sed -e 's|galeraSSTPort=||'` 
    elif [ "$item" != "${item//dbXinetPort=/}" ] ; then
        paasLogXinetPort=`echo "$item" |sed -e 's|dbXinetPort=||'` 
    fi
done

if [ "$passLogHost" = "" ] ; then
    if [ "$paaslogdbHost" = "" ] ; then
        mysqlConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/app/mysql`
        mysqlHost=`echo "$mysqlConfig" | jq  '.installHost' `
        mysqlHost=`convertJsonArrayToString "$mysqlHost"`
    else
        mysqlHost="$paaslogdbHost"
    fi 
    echo "mysqlHost=$mysqlHost"
    paasLogDbPort=`assertPort $paasLogDbPort "$mysqlHost"`
    paasLogIstPort=`assertPort $paasLogIstPort "$mysqlHost" ",$paasLogDbPort,"`
    paasLogSstPort=`assertPort $paasLogSstPort "$mysqlHost" ",$paasLogIstPort,$paasLogDbPort,"`
    paasLogRepPort=`assertPort $paasLogRepPort "$mysqlHost" ",$paasLogSstPort,$paasLogDbPort,$paasLogIstPort,"`
    
    paasLogXinetPort=`assertPort $paasLogXinetPort "$mysqlHost"`
    
    echo "paasLogDbPort=$paasLogDbPort"
    echo "paasLogIstPort=$paasLogIstPort"
    echo "paasLogSstPort=$paasLogSstPort"
    echo "paasLogRepPort=$paasLogRepPort"
    echo "paasLogXinetPort=$paasLogXinetPort"
    paaslogConfs="defaultPort=$paasLogDbPort\ngaleraPort=$paasLogRepPort\ngaleraISTPort=$paasLogIstPort\ngaleraSSTPort=$paasLogSstPort\ndbXinetPort=$paasLogXinetPort\n"
    paaslogConfig=`echo "$paaslogConfig" | jq  'setpath(["app","config","${APP_HOME}/conf/'$paasLogDbApp'-install.conf"]; "'$paaslogConfs'")'`
    paaslogConfs=`echo "$paaslogConfig" | jq  '.app.config."${APP_HOME}/conf/'$paasLogDbApp'-install.conf"' `
    echo "new paaslogConfs=$paaslogConfs"
    echo "$paaslogConfig" > $APP_SRC/$paasLogDbApp/$paasLogDbApp.json 
    $INSTALLER_HOME/sbin/installer zkctl -c set -p $ZKBaseNode/app/$paasLogDbApp -f $APP_SRC/$paasLogDbApp/$paasLogDbApp.json  
    echo "install $paasLogDbApp ..........."
    
    installUrl="http://$deployMasterHostIp:64001/deploy/installApp?installApp=$paasLogDbApp&hostList=$mysqlHost"
    echo "installUrl=$installUrl"
    while [ true ] ;  do
        echo "curl $installUrl"
        installRes=`curl $installUrl`
        echo "$installRes"
        if [ "$installRes" != "${installRes//started background tasks/}" ] ; then
            echo "$installRes"
            break
        else
            sleep 2
        fi
    done
    statusUrl="http://$deployMasterHostIp:64001/deploy/status"
    echo "curl $statusUrl"
    while [ true ] ;  do
        echo "curl $statusUrl"
        installRes=`curl $statusUrl 2>/dev/null `
        if [ "$installRes" = "" ] ; then
            sleep 2
        fi
        code=`echo "$installRes" | jq  '.code'`
        if [ "$code" != "0" ] ; then
            echo "install failed:$installUrl"
            exit 1  
        fi
        deployStatus=`echo "$installRes" | jq  '.result.deployStatus'` #deploySuccess
        if [ "$deployStatus" = "\"running\"" ] ; then
            echo "deployStatus=$deployStatus"
            break
        elif [ "$deployStatus" = "\"deployError\"" ]  ; then
            echo "install failed:$installUrl"
            echo "$installRes"
            exit 1  
        fi
        sleep 2
    done
    echo "wait install $paasLogDbApp .... about 10 - 20 Minutes"
    waitTimes=0
    while [ true ] ;  do
        installRes=`curl $statusUrl 2>/dev/null `
        if [ "$installRes" = "" ] ; then
            echo "install failed:$installUrl"
            exit 1          
        fi
        code=`echo "$installRes" | jq  '.code'`
        if [ "$code" != "0" ] ; then
            echo "install failed:$installUrl"
            exit 1 
        fi
        deployStatus=`echo "$installRes" | jq  '.result.deployStatus'` #deploySuccess
        errorMsg=`echo "$installRes" | jq  '.result.errorMsg'`
        if [ "$deployStatus" = "\"deploySuccess\"" ] ; then
            echo "deployStatus=$deployStatus"
            break
        elif [ "$deployStatus" = "\"deployError\"" ]  ; then
            echo "install failed:$installUrl"
            echo "$installRes"
            exit 1  
        elif [ "$errorMsg" != "" -a "$errorMsg" != "null" ] ; then
            echo "errorMsg=$errorMsg"
        fi
        sleep 2
        ((waitTimes++))
        if [ "`expr $waitTimes % 10 `" = "0" ] ; then
            echo "wait install $paasLogDbApp .... "
        fi
    done
else
    mysqlConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/app/$paasLogDbApp`
    mysqlHost=`echo "$mysqlConfig" | jq  '.installHost' `
    mysqlHost=`convertJsonArrayToString "$mysqlHost"`
fi

PAASLOGDBAPP=`toupper "$paasLogDbApp"`
for mHost in ${mysqlHost//,/ } ; do
    PAASLOGDBAPP_HOME=`ssh $mHost ". /etc/profile.d/${paasLogDbApp}.sh; env " |grep ${PAASLOGDBAPP}_HOME|sed -e "s|${PAASLOGDBAPP}_HOME=||" `
    tmpdbXinetPort=`ssh $mHost cat $PAASLOGDBAPP_HOME/conf/$paasLogDbApp-install.conf |grep dbXinetPort |sed -e "dbXinetPort="`
    break
done 

tmpdbXinetPort=`trim "$tmpdbXinetPort"`
if [ "$tmpdbXinetPort" != "" ] ; then
   paasLogXinetPort="$tmpdbXinetPort"
fi 

paaslogLbConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/loadbalance/services/$paasLogDbApp 2>/dev/null`

if [ "$paaslogLbConfig" = "" ] ; then
    lbMoniPort=`assertPort 48800 "$mysqlHost"  `
    paasLogDbHaPort=`assertPort $paasLogDbHaPort "$mysqlHost" ",$paasLogRepPort,$paasLogDbPort,$paasLogIstPort,$paasLogSstPort,"`
    echo "paasLogDbHaPort=$paasLogDbHaPort"

    paaslogDbLbConf="{\"lbName\":\"$paasLogDbApp\",\"bindHaName\":\"haproxy\",\"statusPort\":\"$lbMoniPort\",\"enable\":true,\"appNames\":[\"$paasLogDbApp\"],\"listenConf\":[{\"policyName\":\"$paasLogDbApp\",\"backupMode\":\"backup\",\"servicePort\":\"$paasLogDbPort\",\"checkProtocol\":\"http\",\"appName\":\"$paasLogDbApp\",\"listenType\":3,\"ssl\":\"false\",\"protocolType\":\"tcp\",\"listenPort\":$paasLogDbHaPort,\"checkPort\":$paasLogXinetPort,\"checkMethod\":\"OPTIONS\",\"checkUrl\":\"* HTTP/1.1\\\\r\\\\nHost:\\\\ www\",\"checkInter\":\"\",\"checkRise\":\"\",\"checkFall\":\"\",\"optionParams\":[]}],\"autoDelete\":true}"
    $INSTALLER_HOME/sbin/installer zkctl -c set -p $ZKBaseNode/loadbalance/services/$paasLogDbApp -d "$paaslogDbLbConf"
else
    listenPort=`echo "$paaslogLbConfig" | jq  '.listenConf[0].listenPort'` 
    checkPort=`echo "$paaslogLbConfig" | jq  '.listenConf[0].checkPort'` 
    servicePort=`echo "$paaslogLbConfig" | jq  '.listenConf[0].servicePort'` 
    
    listenPort="${listenPort//\"/}"
    checkPort="${checkPort//\"/}"
    servicePort="${servicePort//\"/}" 
    paasLogDbHaPort=$listenPort
    echo "paasLogDbHaPort=$paasLogDbHaPort"
    #if [ "$checkPort" != "$paasLogXinetPort" ] ; then
    #fi
    paaslogDbLbConf="{\"lbName\":\"$paasLogDbApp\",\"bindHaName\":\"haproxy\",\"statusPort\":\"$lbMoniPort\",\"enable\":true,\"appNames\":[\"$paasLogDbApp\"],\"listenConf\":[{\"policyName\":\"$paasLogDbApp\",\"backupMode\":\"backup\",\"servicePort\":\"$paasLogDbPort\",\"checkProtocol\":\"http\",\"appName\":\"$paasLogDbApp\",\"listenType\":3,\"ssl\":\"false\",\"protocolType\":\"tcp\",\"listenPort\":$paasLogDbHaPort,\"checkPort\":$paasLogXinetPort,\"checkMethod\":\"OPTIONS\",\"checkUrl\":\"* HTTP/1.1\\\\r\\\\nHost:\\\\ www\",\"checkInter\":\"\",\"checkRise\":\"\",\"checkFall\":\"\",\"optionParams\":[]}],\"autoDelete\":true}"
    $INSTALLER_HOME/sbin/installer zkctl -c set -p $ZKBaseNode/loadbalance/services/$paasLogDbApp -d "$paaslogDbLbConf"
fi

outputTypes=`echo "$deployGobalConfig" | jq  '."deployactor.metrics.output.type"' | sed -e "s|\"||g"`
if [ "$outputTypes" = ""  -o "$outputTypes" = "null" ] ; then
outputTypes="db"
elif [ "$outputTypes" = "db" ] ; then
outputTypes="db"
elif [ "$outputTypes" = "${outputTypes//,db/}" -a "$outputTypes" = "${outputTypes//db,/}"] ; then
outputTypes="$outputTypes,db"
fi

logOutType="outputTypes"
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
fileurl=`echo "$deployGobalConfig" | jq  '."deployactor.metrics.output.file.url"'`
esurl=`echo "$deployGobalConfig" | jq  '."deployactor.metrics.es.file.url"'`
kafkaurl=`echo "$deployGobalConfig" | jq  '."deployactor.metrics.kafka.file.url"'`

otherParams=""
if [  "`checkOutType file`" = "true"  ] ; then
    fileurl=`echo "$deployGobalConfig" | jq  '."deployactor.metrics.output.file.url"'`
    otherParams=" fileurl=$fileurl"
fi
if [  "`checkOutType es`" = "true"  ] ; then
    esurl=`echo "$deployGobalConfig" | jq  '."deployactor.metrics.output.es.url"'`
    otherParams=" $otherParams esurl=$esurl"
fi
if [  "`checkOutType kafka`" = "true"  ] ; then
    kafkaurl=`echo "$deployGobalConfig" | jq  '."deployactor.metrics.output.kafka.url"'`
    otherParams=" $otherParams kafkaurl=$kafkaurl"
fi

. ${APP_BASE}/install/funs.sh
MYSQL=`which mysql 2>/dev/null`
if [ "$MYSQL" = "" ] ; then
    echo "not install mysql client,install mysql client"
    yum install -y mariadb
fi # 
while [ true ];  do
    sleep 2
    haPortStatus="`testHostPort $NEBULA_VIP $paasLogDbHaPort`"
    if [ "$haPortStatus" = "open" -o "$haPortStatus" = "filtered" ] ; then
        echo "test connection:mysql -h $NEBULA_VIP -P $paasLogDbHaPort -u sdba -psdba mysql -e 'select 1' "
        mysql -h $NEBULA_VIP -P $paasLogDbHaPort -u sdba -psdba mysql -e 'select 1'
        res=$?
        if [ "$res" != "0" ] ; then
            echo -n "db not ready , "
            continue
        fi
        break
    fi
    echo "wait paaslogdb $NEBULA_VIP database haproxy  $paasLogDbHaPort started ... "
    sleep 2
done

echo "set deploy log config params ...."
echo "setDeployAppLog.sh \"$outputTypes\" dburl=jdbc:mysql://$NEBULA_VIP:$paasLogDbHaPort/paaslog?autoReconnect=true dbuser=sdba dbpass=sdba dbreserved=5 dbpartition=2 "
cd $BIN
setDeployAppLog.sh $outputTypes dburl=jdbc:mysql://$NEBULA_VIP:$paasLogDbHaPort/paaslog?autoReconnect=true dbuser=sdba dbpass=sdba dbreserved=5 dbpartition=2 $otherParams

systemLBConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/loadbalance/services/systemLB 2>/dev/null`
if [ "$systemLBConfig" = "" ] ; then
   curl http://$deployMasterHostIp:64001/deploy/rebuildSystemHaproxy?force=true
fi 

exit 0
