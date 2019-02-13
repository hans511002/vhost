#!/usr/bin/env bash
#

if [ "$USER" = "" ] ; then
    export USER=`/usr/bin/whoami`
fi
PATH=".:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin:"
for i in /etc/profile.d/*.sh; do
#    if [ "${i//1appenv/}" != "$i" ] ; then
#        `cat /proc/1/cmdline`
#
#    fi
    if [ -r "$i" ]; then
        if [ "$PS1" ]; then
            . "$i"
        else
            . "$i" >/dev/null
        fi
    fi
done

function todate(){
val=${1:0:10}
date --date="@$val" "+%Y-%m-%d %H:%M:%S"
}

function toupper(){
    echo "$@" |awk  '{printf("%s",toupper($1))}'
}

function tolower(){
    echo "$@" |awk  '{printf("%s",tolower($1))}'
}

function testHostPort(){
    if [ "`which tcping >/dev/null 2>&1;echo $?`" = "0" ]; then
        tcping -t 2 "$@" 2>&1 |sed -e 's|.*open.|open|' -e 's|.*closed.|closed|'
    else
        sshPortStatus=$(nmap $1 -p $2 --disable-arp-ping | grep "$2/tcp" | awk '{print $2}')
        if [ "$sshPortStatus" = "filtered" -o "$sshPortStatus" = "open" ]; then
            echo "open"
        fi
    fi
}

function pause()
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

function runcommand {
    ccmmdd="$@"
    if [ "${ccmmdd//|/}" = "$ccmmdd" -a "${ccmmdd//>/}" = "$ccmmdd" ] ; then
        echo "$ccmmdd"
        $ccmmdd
    else
        echo "su -c $ccmmdd"
        su -c "$ccmmdd"
    fi
}

function getDeployZkNode {
    ZKBaseNode=`cat $INSTALLER_HOME/conf/installer.properties |grep "zk.base.node=" | sed  -e "s|zk.base.node=||"`
    clusterName=`cat $INSTALLER_HOME/conf/installer.properties |grep "cluster.name=" | sed  -e "s|cluster.name=||"`
    ZKBaseNode="/$ZKBaseNode/$clusterName"
    echo "$ZKBaseNode"
}

function getAppSrc()
{
    ZKBaseNode=`getDeployZkNode`
    deployGobalConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/gobal`
    APP_SRC=`echo "$deployGobalConfig" | jq  '.APP_SRC' `
    APP_SRC=${APP_SRC//\"/}
    echo "$APP_SRC"
}

function getFileEncode {
    fileName=$1
    fileCode=`file $fileName |sed -e "s#$fileName: ##"`
#    echo "fileCode=$fileCode"
#/etc/sysctl.d/sysctl.conf: UTF-8 Unicode text, with very long lines
    if [ "${fileCode//,/}" = "$fileCode" ]; then
        if [ "${fileCode// text/}" != "$fileCode" ]; then
            trim ${fileCode// text/}
        elif [ "$fileCode" = "current ar archive" ]; then
            echo "staticlib"
        elif [ "${fileCode//symbolic link/}" != "$fileCode" ]; then
            echo "symbolic"
        elif [ "${fileCode//POSIX tar/}" != "$fileCode" ]; then
            echo "tar"
        elif [ "${fileCode//directory/}" != "$fileCode" ]; then
            echo "directory"
        elif [ "${fileCode//empty/}" != "$fileCode" ]; then
            echo "empty"
        else
            echo "$fileCode"
        fi
    elif [ "${fileCode// text,/}" != "$fileCode" ]; then
        fileCode=`echo $fileCode|sed -e "s|text,.*||"`
        fileCode=`trim ${fileCode//text/}`
        trim ${fileCode//Unicode/}
    elif [ "${fileCode//XML /}" != "$fileCode" -a  "${fileCode// text/}" != "$fileCode" ]; then
        fileCode=`echo $fileCode|sed -e "s|.*,||"`
        fileCode=`trim ${fileCode//text/}`
        trim ${fileCode//Unicode/}
    elif [ "${fileCode// source/}" != "$fileCode" -a  "${fileCode// text/}" != "$fileCode" ]; then
        fileCode=`echo $fileCode|sed -e "s|.*,||"`
        fileCode=`trim ${fileCode//text/}`
        trim ${fileCode//Unicode/}
    elif [ "${fileCode// shell script/}" != "$fileCode" -a  "${fileCode// text/}" != "$fileCode" ]; then
        fileCode=`echo $fileCode|sed -e "s|.*,||" -e "s|text.*|text|"   `
        fileCode=`trim ${fileCode//text/}`
        trim ${fileCode//Unicode/}
    elif [ "${fileCode//executable/}" != "$fileCode" ]; then
        echo "executable"
    elif [ "${fileCode//shared object/}" != "$fileCode" ]; then
        echo "sharedlib"
    elif [ "${fileCode//compressed data/}" != "$fileCode" ]; then
        trim `echo "$fileCode"|sed -e "s|compressed data.*||"`
    elif [ "${fileCode//LSB relocatable/}" != "$fileCode" ]; then
        echo "staticlib"
    fi
}

findPPidPts(){
PID=$1
PID="${PID:=$PPID}"
#echo "PID=$PID"
s=`ps -ef|grep $PID|grep -v grep|grep "pts/"|grep bash|wc -l`
if [ "$s" -gt "0" ] ; then
    echo "true"
else
    PID=`ps -fp $PID|awk '{print $3}'|grep -v PPID`
    if [ "$PID" = "1" ] ; then
         echo "false"
    else
        findPPidPts $PID
    fi
fi
}

findPPidDeployer(){
PID=$1
PID="${PID:=$PPID}"
#echo "PID=$PID"
s=`ps -ef|grep $PID|grep -v grep|grep "deployactor.Deployactor"|wc -l`
if [ "$s" -gt "0" ] ; then
    echo "true"
else
    PID=`ps -fp $PID|awk '{print $3}'|grep -v PPID`
    if [ "$PID" = "1" ] ; then
         echo "false"
    else
        findPPidDeployer $PID
    fi
fi
}

beginErrLog(){
proInDeployer="`findPPidDeployer`"
export proInDeployer
if [ "proInDeployer" != "true" ] ; then
export tmpFile=`mktemp /tmp/appOpt.$PPID.XXXXXX`
exec 4>&2
exec 2>$tmpFile
fi
}

endErrLog(){
if [ "proInDeployer" != "true" -a "$tmpFile" != "" -a -f "$tmpFile" ] ; then
    exec 2>&4   # stderr back to console
    cat $tmpFile
    rm -rf $tmpFile
fi
}

#不传参数适用于各应用的start stop命令
writeOptLog(){
_res=$?
binShell=$0
binShell="${binShell//.sh/}"
dirNme=`dirname $binShell`
binShell="${binShell//$dirNme\//}"
binShell="${binShell/_/ }"
#echo "binShell=$binShell"
binShell=($binShell)
_ORDER="${binShell[0]}"
_APPNAME="${binShell[1]}"

APPNAME=$1
RES=$2
ORDER=$3
OPTUSER=$4
RESMSG=$5
COMMAND=$6
COMMAND="${COMMAND:=$0}"

isPTS=`findPPidPts`
proInDeployer="`findPPidDeployer`"
if [ "$isPTS" = "true" -a "$proInDeployer" != "true" ] ; then
    APPNAME=${APPNAME:=$_APPNAME}
    RES=${RES:=$_res}
    ORDER=${ORDER:=$_ORDER}
    OPTUSER=${OPTUSER:=PTS/$USER}
    if [ "$RESMSG" = "" ] ; then
        err=`endErrLog`
    else
        endErrLog
    fi
    RESMSG=${RESMSG:=$err}
    DATETIME="`date "+%s"`000"
    YYYYMM="`date "+%Y%m"`"
    RESMSG=`echo "$RESMSG"|awk -F";;;;" '{printf("%s\\\\n",$1)}'`

    echo "{\"appName\":\"$APPNAME\",\"res\":$RES,\"order\":\"$ORDER\",\"dateTime\":$DATETIME,\"command\":\"$COMMAND\",\"hostName\":\"$HOSTNAME\",\"msg\":\"$RESMSG\",\"user\":\"$OPTUSER\"}" >>${LOGS_BASE}/installer/app_opt.log.$YYYYMM
    if [ "$err" != "" ] ; then
        echo $err
    fi
    ${INSTALLER_HOME}/sbin/installer zk set  `getDeployZkNode`/appOptLog "{\"appName\":\"$APPNAME\",\"res\":$RES,\"order\":\"$ORDER\",\"dateTime\":$DATETIME,\"command\":\"$COMMAND\",\"hostName\":\"$HOSTNAME\",\"msg\":\"$RESMSG\",\"user\":\"$OPTUSER\"}"
fi
exit $_res
}

getUserID(){
userName=$1
userName=${userName:=$USER}
id $userName|sed -e 's|(.*||' -e 's|uid=||'
}

export USERID=`getUserID`

checkRunUser(){
APP_NAME=$1
appUser=`env|grep "^${APP_NAME}_user="|sed -e 's|.*=||'`
if [ "$appUser" = "" ] ; then
    appUser="root"
fi

if [ "$appUser" != "$USER" ] ; then
    echo "not install user:Please use to $appUser running "
    exit 1
fi

if [ "$USERID" != "0" ] ; then
    if [ "$DOCKER_OTHER_PARAMS" = "${DOCKER_OTHER_PARAMS//--user/}" ] ; then
        DOCKER_OTHER_PARAMS="$DOCKER_OTHER_PARAMS --user $USERID "
    else
        DOCKER_OTHER_PARAMS="$DOCKER_OTHER_PARAMS --user $USERID "
    fi
fi
}

copyAppEnvFile(){
appName=$1
envFileName=$2
envFileName="${envFileName:=$appName}"
appHostList="`getAppHosts $appName`"
appHostList="${appHostList//,/ }"
for HOST in $appHostList ; do
    envFile=`ssh $HOST ls  /etc/profile.d/$envFileName.sh 2>/dev/null`
    if [ "$envFile" != "" ] ; then
        scp $HOST:/etc/profile.d/$envFileName.sh /etc/profile.d/$envFileName.sh
        if [ "$?" = "0" ] ; then
            exit 0
        fi
    fi
done
}

#DOCKER_OTHER_PARAMS= -v ${APP_BASE}/ipconf.xml:/ipconf.xml -v ${APP_BASE}/publicsetting.xml:/publicsetting.xml  -v /etc/localtime:/etc/localtime:ro -e MASTER_HOSTNAME=$HOSTNAME
#JOVE_RESOURCES= --cpu-shares 1024 --cpuset-cpus=17-22   -m 3210m --memory-reservation 1926m --oom-kill-disable --memory-swappiness=80
convertDockerRunToService(){
runPars="$@"
runPars=($runPars)
count=${#runPars[@]}
servicePars=""
for ((i=0; i <count;i++ )) do
    type="${runPars[$i]}"
    if [ "$type" = "-v" ] ; then
        ((i++))
        val="${runPars[$i]}"
        val=(${val//:/ })
        servicePars="$servicePars --mount type=bind,src=${val[0]},dst=${val[1]} "
    elif [ "${type}" = "-p" ] ; then
        ((i++))
        val="${runPars[$i]}"
        servicePars="$servicePars --port $val "
    elif [ "${type}" = "-e" ] ; then
        ((i++))
        val="${runPars[$i]}"
        servicePars="$servicePars -e $val "
    elif [ "${type}" = "-m" ] ; then
        ((i++))
        val="${runPars[$i]}"
        servicePars="$servicePars --limit-memory $val "
    elif [ "${type}" = "--net" -o "${type}" = "--network" ] ; then
        ((i++))
        val="${runPars[$i]}"
        servicePars="$servicePars --network $val "
    elif [ "${type}" != "${type//--net=/}" -o "${type}" != "${type//--network=/}"   ] ; then
        val="${type//--net=/}"
        val="${type//--network=/}"
        servicePars="$servicePars --network $val "
    elif [ "${type}" = "--name"  ] ; then
        ((i++))
        val="${runPars[$i]}"
        servicePars="$servicePars --name $val "
    elif [ "${type}" = "--user" -o "${type}" = "-u" ] ; then
        ((i++))
        val="${runPars[$i]}"
        servicePars="$servicePars --user $val "
    elif [ "${type}" != "${type//-u=/}" -o "${type}" != "${type//--user=/}"   ] ; then
        val="${type//--user=/}"
        val="${type//-u=/}"
        servicePars="$servicePars --user $val "
    elif [ "${type}" = "--add-host"  ] ; then
        ((i++))
        val="${runPars[$i]}"
        servicePars="$servicePars --host $val "
    elif [ "${type}" != "${type//--add-host=/}"  ] ; then
        val="${type//--add-host=/}"
        servicePars="$servicePars --host $val "
    elif [ "${type}" = "--dns"  ] ; then
        ((i++))
        val="${runPars[$i]}"
        servicePars="$servicePars --dns $val "
    elif [ "${type}" != "${type//--dns=/}"  ] ; then
        val="${type//--dns=/}"
        servicePars="$servicePars --dns $val "
    fi
done
echo "$servicePars"
}

errorExit(){
res=$1
msg=$2
if [ "$res" != "0" ] ; then
    echo $msg
    exit 1
fi
}

check_app(){
    allApps=",${ALL_APP},"
    if [ "${allApps//,$1,/}" = "$allApps"  ] ; then
            echo "false"
    else
      echo "true"
    fi
}

checkApp(){
    allApps=",${ALL_APP},"
	if [ "${allApps//,$1,/}" = "$allApps"  ] ; then
		echo "false"
	else
	  echo "true"
	fi
}

addEnvApp(){
addAppName="$1"
if [ "$addAppName" = "" ] ; then
    echo "addAppName is null"
   return
fi
. /etc/profile.d/1appenv.sh
if `echo ",$ALL_APP," | grep ",$addAppName,"  > /dev/null ` ; then
echo "exists app $addAppName in ALL_APP "
else
sed -i -e "s|export ALL_APP=\"|export ALL_APP=\"$addAppName,|"  /etc/profile.d/1appenv.sh
echo "add $addAppName in ALL_APP"
fi
}

delEnvApp(){
delAppName="$1"
if [ "$delAppName" = "" ] ; then
    echo "delAppName is null"
   return
fi
. /etc/profile.d/1appenv.sh
if `echo ",$ALL_APP," | grep ",$delAppName,"  > /dev/null ` ; then
    sed -i -e "s|,$delAppName,|,|"  /etc/profile.d/1appenv.sh
    sed -i -e "s|export ALL_APP=\"$delAppName,|export ALL_APP=\"|"  /etc/profile.d/1appenv.sh
    sed -i -e "s|export CLUSTER_APP=\"$delAppName,|export CLUSTER_APP=\"|"  /etc/profile.d/1appenv.sh
    sed -i -e "s|export ALL_APP=\"\(.*\),$delAppName\"|export ALL_APP=\"\1\"|"  /etc/profile.d/1appenv.sh
    sed -i -e "s|export CLUSTER_APP=\"\(.*\),$delAppName\"|export CLUSTER_APP=\"\1\"|"  /etc/profile.d/1appenv.sh
echo "del $delAppName in ALL_APP"
else
echo "$delAppName not in ALL_APP"

fi
}

cmpVersion(){
	v1=$1
	v2=$2
	v1=${v1//./ }
	v2=${v2//./ }
	V1=($v1)
	V2=($v2)
	l1=${#V1[@]}
	l2=${#V2[@]}
	len=0
	while true ;  do
	  v1=-1
	  v2=-1
	  if [ "$l1" -gt "$len" ] ; then
	  	v1=${V1[$len]}
	  fi
	  if [ "$l2" -gt "$len" ] ; then
	  	v2=${V2[$len]}
	  fi
	  #echo "v1=$v1  v2=$v2  l1=$l1 l2=$l2"
	  ((len++))
		if  [ "$v1" -eq "-1" -a "$v2" -eq "-1" ] ; then   # (v1 == -1 && v2 == -1) {
				echo 0
				break
		elif [ "$v1" -gt "-1" -a "$v2" -eq "-1" ] ; then #  (v1 > -1 && v2 == -1) {
				if [ "$v1" = "0" ] ; then
					continue
				fi
				echo "1"
				break
		elif [ "$v1" -eq "-1" -a "$v2" -gt "-1" ] ; then #  (v1 == -1 && v2 > -1) {
				if [ "$v2" = "0" ] ; then
					continue
				fi
				echo "-1"
				break
		else
				if [ "$v1" -gt "$v2" ] ; then
					echo "1"
					break
				elif [ "$v1" -lt "$v2" ] ; then
				   echo "-1"
					 break
			  else
			  	 continue
				fi
		fi
	done
}

trim(){
echo "$1" | grep -o "[^ ]\+\( \+[^ ]\+\)*"
}

testHostNmap(){
    type=`testHostPort $1  22  `
    if [ "$type" = "open" ] ; then
        echo "true"
    else
        echo "false"
    fi
}

getHostIPFromPing(){
    thisIP=$(ping $1 -c 1  -W 1 | grep "icmp_seq" |grep from|sed -e 's|.*(||' -e 's|).*||')
    if [ "$thisIP" = "" ] ; then
        thisIP=$(ping $1 -c 1 -W 1 | grep "bytes of data" |awk  '{print $3}'|sed -e 's|.*(||' -e 's|).*||')
    fi
    echo "$thisIP"
}

getAppHome(){
    app_name=$1
    appHome=`echo "$app_name" |awk  '{printf("%s_HOME",toupper($1))}' `
    appHostRel=`echo "$app_name" |awk '{printf("%s_hosts",tolower($1))}' `
    appName=`echo "$app_name" |awk '{printf("%s",tolower($1))}' `
    appHosts=`env|grep -E ^$appHostRel=  |sed -e "s/$appHostRel=//"`
    APP_HOME=`env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
    if [ "$APP_HOME" = ""  ] ; then
        for HOST in ${appHosts//,/ } ; do
            APP_HOME=`ssh $HOST env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
            if [ "$APP_HOME" != ""  ] ; then
                 break
            fi
        done
     fi
    echo "$APP_HOME"
}

getAppName(){
APP_HOME="$1"
_APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
echo "$appName"
}

getAppVer(){
    app_name=$1
    APP_HOME=`getAppHome $app_name`
    if [ "$APP_HOME" != ""  ] ; then
        APPPARDIR=`dirname $APP_HOME`
        echo "${APP_HOME//$APPPARDIR\/$app_name-/}"
    fi
}

getAppHosts(){
    app_name=$1
    appHostRel=`echo "${app_name}_hosts" |awk '{printf("%s",tolower($1))}' `
    appHosts=`env|grep -E ^$appHostRel=  |sed -e "s/$appHostRel=//"`
    if [ "$appHosts" = ""  ] ; then
        appHostRel=`echo "$app_name" |awk '{printf("%s_docker_hosts",tolower($1))}' `
		appHosts=`env|grep -E ^$appHostRel=  |sed -e "s/$appHostRel=//"`
    fi
    if [ "$appHosts" = ""  ] ; then
        appHostRel=`echo "${app_name}_hosts" |awk '{printf("%s",tolower($1))}' `
        appHome=`echo "$app_name" |awk '{printf("%s_HOME",toupper($1))}' `
        appName=`echo "$app_name" |awk '{printf("%s",tolower($1))}' `
        for HOST in ${CLUSTER_HOST_LIST//,/ } ; do
            appHosts=`ssh $HOST env|grep -E ^$appHostRel=  |sed -e "s/$appHostRel=//"`
            if [ "$appHosts" != "" ] ; then
                break
            fi
            APP_HOME=`ssh $HOST env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
            if [ "$APP_HOME" != ""  ] ; then
                if [ "`ssh $HOST  ls $APP_HOME/conf/servers 2>/dev/null`" != "" ] ; then
                    appHosts=`ssh $HOST cat $APP_HOME/conf/servers`
                fi
            fi
            if [ "$appHosts" != "" ] ; then
                break
            fi
        done
        if [ "$appHosts" = "" ] ; then
           appHosts=${CLUSTER_HOST_LIST//,/ }
        fi
    else
        appHosts=${appHosts//,/ }
    fi
    appHosts=`trim "$appHosts"`
    echo "$appHosts"
}

isInstallHaproxy(){
    res="true"
    if [ "${ALL_APP//haproxy,/}" = "$ALL_APP" -a  "${ALL_APP//,haproxy/}" = "$ALL_APP"  ] ; then
       res="false"
    fi
    echo "$res"
}

get_before_dates()
{
 yyyymmdd=$1
 num=$2
 for ((i=0;i<num;i=i+1))
do
  yyyymmdd=`get_before_date $yyyymmdd`
done

 echo $yyyymmdd
}

get_before_date()
{
	Y=`expr substr $1 1 4`
	M=`expr substr $1 5 2`
	D=`expr substr $1 7 2`
	YY=`expr $Y - 1`
	MM=`expr $M - 1`
	DD=`expr $D - 1`
	MM=`printf "%02d" $MM`
	DD=`printf "%02d" $DD`
	dd=$Y$MM
	dad=`get_mon_days $dd`
	be_date=$Y$M$DD
    if [ "$D" == "01" ] ; then
		if [ $M -ne 01 ]
		then
			be_date=$Y$MM$dad
		else
			be_date=$YY"1231"
		fi
	fi
	echo $be_date
}

get_before_month()
{
	Y=`echo $1|cut -c 1-4`
	M=`echo $1|cut -c 5-6`
	D=01
	day=$Y$M$D
	day=`get_before_date $day`
	before_month=`echo $day|cut -c 1-6`
	echo $before_month
}

get_mon_days()
{
    Y=`expr substr $1 1 4`
	M=`expr substr $1 5 2`
	case $M in
    01|03|05|07|08|10|12)
      dd=31 ;;
   04|06|09|11)
      dd=30 ;;
    *)
    if [ $((Y%4)) -eq 0 ] ; then
	   dd=29
	else
	   dd=28
	fi
    ;;
  esac
echo $dd
}

isDnsHaHost(){
    if [ "`check_app haproxy`" = "true" ]; then
        if [ "`check_app keepalived`" = "true" ]; then
             echo "false"
        else
             echo "true"
        fi
    else
        echo "false"
    fi
}
checkIPAddr(){
    echo $1|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" > /dev/null; 
    if [ $? -ne 0 ] ; then 
        echo false 
    fi 
    ipaddr=$1 
    a=`echo $ipaddr|awk -F . '{print $1}'` 
    b=`echo $ipaddr|awk -F . '{print $2}'` 
    c=`echo $ipaddr|awk -F . '{print $3}'` 
    d=`echo $ipaddr|awk -F . '{print $4}'` 
    for num in $a $b $c $d 
    do 
        if [ $num -gt 255 ] || [ $num -lt 0 ] ; then 
            echo false 
        fi 
    done 
    echo true 
} 

getDnsIpList(){
    if [ "`check_app keepalived`" = "false" -a  "`check_app haproxy`" = "false" ] ; then
     #not install keepalived and haproxy , all host ins dns
        clusHostLists="${CLUSTER_HOST_LIST}"
        clusIpLists="${CLUSTER_IP_LIST}"
        echo " mod env NEBULA_VIP=$PRODUCT_DOMAIN" >&2
        sed -i -e "s@export NEBULA_VIP=.*@export NEBULA_VIP=$PRODUCT_DOMAIN@" /etc/profile.d/1appenv.sh
    else # ins keepalived,only ka host ins dns
        if [ "`check_app keepalived`" = "true" ]; then
             kaHostList="`getAppHosts keepalived`"
        else
             kaHostList="`getAppHosts haproxy`"
        fi
        clusHostLists=${kaHostList}
        clusIpLists=""
        for HOST in ${clusHostLists//,/ } ; do
            HOSTIP=`getHostIPFromPing $HOST`
            if [ "$clusIpLists" = "" ] ; then
                clusIpLists="$HOSTIP"
            else
                clusIpLists="$clusIpLists,$HOSTIP"
            fi
        done
    fi
    echo "$clusIpLists"
}

getDnsHostList(){
    if [ "`check_app keepalived`" = "false" -a  "`check_app haproxy`" = "false" ] ; then
     #not install keepalived and haproxy , all host ins dns
        clusHostLists="${CLUSTER_HOST_LIST}"
        clusIpLists="${CLUSTER_IP_LIST}"
        echo " mod env NEBULA_VIP=$PRODUCT_DOMAIN"
        sed -i -e "s@export NEBULA_VIP=.*@export NEBULA_VIP=$PRODUCT_DOMAIN@" /etc/profile.d/1appenv.sh
    else # ins keepalived,only ka host ins dns
        if [ "`check_app keepalived`" = "true" ]; then
             kaHostList="`getAppHosts keepalived`"
        else
             kaHostList="`getAppHosts haproxy`"
        fi
        clusHostLists=${kaHostList}
        clusIpLists=""
        for HOST in ${clusHostLists//,/ } ; do
            HOSTIP=`getHostIPFromPing $HOST`
            if [ "$clusIpLists" = "" ] ; then
                clusIpLists="$HOSTIP"
            else
                clusIpLists="$clusIpLists,$HOSTIP"
            fi
        done
    fi
    echo "$clusHostLists"
}

registryLogin(){
. /etc/profile.d/registry.sh
echo "login to  registry : docker login $REGISTRY_DOMAIN:5000  -u $REGISTRY_USER -p  $REGISTRY_PASS"
res=1
retTimes=0
while [ "$res" != "0" ]  ;  do
    docker login $REGISTRY_DOMAIN:5000  -u $REGISTRY_USER -p  $REGISTRY_PASS
    res=$?
    if [ "$res" = "0" ] ; then
        break
    else
        ping $REGISTRY_DOMAIN -c 1
        if [ "$?" != "0" ] ; then
            for HOST in ${$dns_hosts//,/ } ; do
                ssh $HOST service named restart
            done
        fi
    fi
    ((retTimes++))
   if [ "$retTimes" -gt "7" ] ; then
       break;
   fi
done
errorExit $res "docker login to registry faield : docker login $REGISTRY_DOMAIN:5000  -u $REGISTRY_USER -p  $REGISTRY_PASS"
}

runCMD(){
   cmd=$1
   sltime=$2
   retry=$3
   if [ "$retry" = "" ]; then
       retry=1
   fi
   tryTime=0
    while [[ $tryTime -lt $retry ]] ; do
        ((tryTime++))
       echo "====================> $cmd"
       $cmd
        RETVAL=$?
        if [ "$RETVAL" = "0" ] ; then
          break;
        fi
        if [ "$5" != "" ]; then
           $5
        fi
    done
    if [ "$RETVAL" -ne "0" ] ; then
       echo -e "[\033[1;31mRun Failed\033[0m]: $cmd"
       exit $RETVAL
    fi
    return $RETVAL
}

checkLocalApp(){
    if [ "`checkApp $1`" = "true" ] ; then
        appHosts=`getAppHosts $1`
	    if [ "${appHosts//$LOCAL_HOST}" != "$appHosts" ] ; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

runHOSTCMD(){
    appName=$1
    shift
    for host in `getAppHosts $appName` ; do
        echo "====================> ssh $host \"$@\""
        ssh $host $@
        if [ "$?" -ne "0" ]; then
            echo -e "[\033[1;31mRun Failed\033[0m]: $@"
            exit 1
        fi
    done
}

runAppOnFisrtHost(){
    appName=$1
    shift
    for HOST in `getAppHosts $appName` ; do
        runCMD "ssh $HOST \"$1\"" $2 $3 $4 "ssh $HOST $5"
        break
    done
}

appCtl(){
    appName=$1
    COMMAND=$2
    isCluster=$3
    PCHOST=$4
    COMMAND=${COMMAND:=start}
    appHome=`echo "$appName" |awk '{printf("%s_HOME",toupper($1))}' `
    appName=`echo "$appName" |awk '{printf("%s",tolower($1))}' `
    for host in `getAppHosts $appName` ; do
        if [ "$PCHOST" != "" ] ; then
            if [ "${PCHOST//$host/}" = "${PCHOST}" ] ; then
                continue
            fi
        fi
        APP_HOME=`ssh $host env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
        echo "appHome=$appHome appName=$appName"
        if [ "$APP_HOME" = ""  ] ; then
            appHome=`echo "$app_name" |awk '{printf("%s_DOCKER_HOME",toupper($1))}' `
    		APP_HOME=`ssh $host env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
    		if [ "$APP_HOME" = ""  ] ; then
     		     echo " app $app_docker not install completed"
    		     return
             fi
        fi

        echo -e "\033[1;36m=====================================================================================================================================\033[0m"
        if [ "$isCluster" = "true" ] ; then
            echo -e "\033[1;34m========================================> $APP_HOME/sbin/${COMMAND}_${appName}_cluster.sh <========================================\033[0m"
            startFile=`ssh $host ls ${APP_HOME}/sbin/${COMMAND}_${appName}_cluster.sh 2>/dev/null`
            if [ "$startFile" = "" ] ; then
                echo "$host not find $appName ${COMMAND} shell, skipped!"
                break
            fi        
        else
            echo -e "\033[1;34m========================================> $APP_HOME/sbin/${COMMAND}_${appName}.sh <========================================\033[0m"
            startFile=`ssh $host ls ${APP_HOME}/sbin/${COMMAND}_${appName}.sh 2>/dev/null`
            if [ "$startFile" = "" ] ; then
                echo "$host not find $appName ${COMMAND} shell, skipped!"
                break
            fi
        fi
        if [ "$startFile" != "" ] ; then
            ssh $host ${startFile}
            break
        fi
    done
}

start_all_apps(){
    isCluster=$1
    excludeApps=$2
    COMMAND=$3
    COMMAND=${COMMAND:=start}
    allApps=${ALL_APP//,/ }
    # echo "isCluster=$isCluster"
    # echo "excludeApps=$excludeApps"

    for app_docker in $allApps ; do
        isInExclude="false"
        for xapp in $excludeApps ; do
            if [ "$xapp" = "$app_docker" ] ; then
                isInExclude="true"
                break
            fi
        done
        if [ "$isInExclude" = "true" ] ; then
              continue
        fi

        app_name=${app_docker//-/_}
        appHome=`echo "$app_name" |awk  '{printf("%s_HOME",toupper($1))}' `
        appName=`echo "$app_name" |awk  '{printf("%s",tolower($1))}' `
        appCtl $appName ${COMMAND} "$isCluster"
    done
}

checkHostDisk(){
    checkDisk="/ $INSTALL_ROOT"
    diskCheck=`df $checkDisk |grep -v 1K |sed  -e 's|%||'|awk '{printf("%s ",$5)}'`
    logFile="${LOGS_BASE}/syslog/disk_check.log.`date "+%Y%m%d"`"
    mkdir -p ${LOGS_BASE}/syslog
    echo "`date` check disk used
`df $checkDisk ` "| tee -a $logFile
    checkDisk=($checkDisk)
    diskCheck=($diskCheck)
    c=${#checkDisk[@]}
    for ((i=0; i <c;i++ )) do
        if [ "${diskCheck[$i]}" -ge "90" ] ; then
            echo "`date`
===================warn======${checkDisk[$i]} Used ${diskCheck[$i]}===============================================================
Please clear the disk or expand the capacity, otherwise the disk utilization rate will reach 97 when the application will be stopped.
The execution log automatic cleaning commands are as follows: "  | tee -a $logFile
            resvDay=10
            while [ "$resvDay" -gt 3 ] ; do
                echo "exec: $bin/clean_logs.sh $LOGS_BASE $resvDay  "| tee -a $logFile
                rmLogs="`$bin/clean_logs.sh $LOGS_BASE $resvDay |grep 'rm -rf'`"
                if [ "$rmLogs" != "" ] ; then
                    echo "$rmLogs" | tee -a $logFile
                    break
                fi
            done
        fi
        if [ "${diskCheck[$i]}" -ge "97" ] ; then
            stopHostAllApp "disk full "
            exit $1
        fi
    done
    echo "" >> $logFile
}

checkHostData(){
    if [ "${mysql_hosts}" != "" ] ; then
        if [ "${mysql_hosts//$LOCAL_HOST/}" != "${mysql_hosts}" ] ; then
            if [ -f "$MYSQL_HOME/sbin/start_mysql.sh" -a -d "${DATA_BASE}/mysql/mysql" ] ; then  # 解决安装过程中误停
                #判断数据盘是否存在（或可访问），如果不存在（或可访问）停掉本机的docker，再停止本机的服务#
                mysqldb=`ls ${DATA_BASE}/mysql 2>&1 | wc -l`
                needStop="false"
                if [ "$mysqldb" -lt "5" ] ; then
                    needStop="true" 
                    sleep 20
                    ##################
                    mysqldb=`ls ${DATA_BASE}/mysql/mysql 2>&1 |wc -l `
                    if [ "$mysqldb" -lt "10"  ] ; then
                        stopHostAllApp "mysql data lost ,stop this host"
                        exit 1
                    fi
                fi
            fi
        fi
    fi
}

checkHostApp(){
    appSize=`ls ${APP_BASE} 2>/dev/null |wc -l     `
    if [ "$appSize" -lt "1" ] ; then
        stopHostAllApp "install disk lost ,stop this host"
    fi
}

stopHostAllApp(){
    mkdir -p ${LOGS_BASE}/syslog
    logFile="${LOGS_BASE}/syslog/app_check.log.`date "+%Y%m%d"`"
    echo "`date`
error:$@ "  | tee -a $logFile
    echo "exec: /bin/systemctl stop docker.service"  | tee -a $logFile
    /bin/systemctl stop deploy.service   | tee -a $logFile
    docker stop $(doker ps -qa)
    /bin/systemctl stop docker.service   | tee -a $logFile
    #shutdown -r
    #reboot
}

checkHostHealthy(){
    echo "`date` check app dir "
    checkHostApp
    if [ "$1" = "" ] ; then
        echo "`date` check mysql data dir "
        checkHostData
    fi
    echo "`date` check disk use rate "
    checkHostDisk
}

testHostNamed(){
    type=`testHostPort  $1  53  `
    if [ "$type" = "open" ] ; then
        echo "true"
    else
        echo "false"
    fi
}

function getCheckScript() {
    app=$1
    appHome=`getAppHome $app`
    if [ "$appHome" != "" ] ; then
        appHosts=`env | grep ${app}_hosts | awk -F= '{print $NF}'`
        appHosts=(${appHosts//,/ })
        checkScript=(`ssh ${appHosts[0]} "ls ${appHome}/sbin/check_${app}*_cluster*.sh 2>/dev/null" | grep '\.sh$'`)
        if [ "${#checkScript[@]}" = "1" ]; then
            echo ${checkScript[0]}
        fi
    fi
}
