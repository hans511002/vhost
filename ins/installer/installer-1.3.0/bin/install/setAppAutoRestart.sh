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
stopAllAppAutoRestart=$1

if [ "$stopAllAppAutoRestart" != "true" -a "$stopAllAppAutoRestart" != "false" ] ; then
    echo "exp:setAppAutoRestart.sh true|false"
    exit 1
fi
. ${APP_BASE}/install/funs.sh

appIncs="$2"
appIncs=",$appIncs,"
ZKBaseNode=`getDeployZkNode`
appList=`$INSTALLER_HOME/sbin/installer zkctl -c ls -p $ZKBaseNode/app`
appList="${appList// /}"
appList="${appList//]/}"
appList="${appList//[/}"
echo "appList=$appList"

res=0
for appName in ${appList//,/ } ; do
    if [ "$appIncs" != ",," -a "${appIncs//,$appName,/}" != "$appIncs" ] ; then
        continue
    fi
    appConf=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/app/$appName`
    isAutoRestart=`echo "$appConf" | jq '.app.isAutoRestart'|sed -e 's/"//g'`
    if [ "$isAutoRestart" != "" ] ; then
        echo "app.$appName.isAutoRestart=$isAutoRestart"
        if [ "$isAutoRestart" = "$stopAllAppAutoRestart" ] ; then
            continue
        fi
        appConf=`echo "$appConf" | jq  'setpath(["app","isAutoRestart"]; "'$stopAllAppAutoRestart'")'`
    else
        isAutoRestart=`echo "$appConf" | jq '.cluster.isAutoRestart'|sed -e 's/"//g'`
        echo "cluster.$appName.isAutoRestart=$isAutoRestart"
        if [ "$isAutoRestart" != "" ] ; then
            if [ "$isAutoRestart" = "$stopAllAppAutoRestart" ] ; then
                continue
            fi
            appConf=`echo "$appConf" | jq  'setpath(["cluster","isAutoRestart"]; "'$stopAllAppAutoRestart'")'`
        else
            appConf=`echo "$appConf" | jq  'setpath(["app","isAutoRestart"]; "'$stopAllAppAutoRestart'")'`
        fi
    fi
    echo "      set $appName isAutoRestart to $stopAllAppAutoRestart wait......."
    tmpFile=`mktemp /tmp/$appName.XXXXXX`
    echo "$appConf" >$tmpFile
    echo -n "      exe: $INSTALLER_HOME/sbin/installer zkctl -c set -p $ZKBaseNode/app/$appName -f $tmpFile ... "
    $INSTALLER_HOME/sbin/installer zkctl -c set -p $ZKBaseNode/app/$appName -f $tmpFile
    res=$?
    rm -rf $tmpFile
    if [ "$res" != "0" ] ; then
        echo " set failed"
        break
    else
        echo " set success"
    fi
done

if [ "$res" = "0" ] ; then
    echo "set all app isAutoRestart success"
    cmd.sh service deploy restart
else
    echo "set all app isAutoRestart failed"
fi
exit $res
