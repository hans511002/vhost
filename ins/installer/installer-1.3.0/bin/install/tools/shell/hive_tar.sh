#!/bin/bash
. /etc/bashrc

bin=$(pwd)
appDir=$1
if [ -z "$appDir" ]; then
    echo "Usage: $0 AppDir"
    echo "eg: $0 /app_src/hivecore/hivecore-1.0.0"
    exit 1
elif [ ! -d "$appDir" ]; then
    echo "[ERROR] $appDir: No such directory"
    exit 1
fi

appDirA=${appDir%/}
appDirB=${appDirA##*/}
appVersion=${appDirB##*-}
appName=${appDirB%-${appVersion}}

if [ "$appVersion" != "$appName" ]; then
    appDirC=${appDirA%${appName}-${appVersion}}
else
    appDirC=${appDirA%${appName}}
fi

if [ ! -d "$appDirC" ]; then
    appDirC=$bin
fi

# echo appDirA=$appDirA
# echo appDirB=$appDirB
# echo appDirC=$appDirC
# echo appName=$appName
# echo appVersion=$appVersion

expr ${appVersion//./} + 0 >/dev/null 2>&1 || { echo "[ERROR] please check..."; exit 1; }
for i in $appDirA $appDirB $appDirC $appName; do
    if [ -z "$i" ]; then
        echo "[ERROR] please check..."
        exit 1
    fi
done

echo "cd $appDirC && tar -czf ${appDirB}.tar.gz ${appDirB} && md5sum ${appDirB}.tar.gz > ${appDirB}.tar.gz.md5"
cd $appDirC && tar -czf ${appDirB}.tar.gz ${appDirB} && sleep 0.5 && md5sum ${appDirB}.tar.gz > ${appDirB}.tar.gz.md5

function regTozk() {
if [ "$INSTALLER_HOME" != "" ] ; then
    echo "this host installed deploy , parse reg to zk"
    ZKBaseNode=`cat $INSTALLER_HOME/conf/installer.properties |grep "zk.base.node=" | sed  -e "s|zk.base.node=||"`
    clusterName=`cat $INSTALLER_HOME/conf/installer.properties |grep "cluster.name=" | sed  -e "s|cluster.name=||"`
    ZKBaseNode="/$ZKBaseNode/$clusterName"
    APP_SRC=`$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode/gobal|jq '.APP_SRC'`
    APP_SRC="${APP_SRC//\"/}"
    echo "APP_SRC=$APP_SRC"
    if [ ! -d "$APP_SRC" ] ; then # 可操作
        echo "installed but not access APP_SRC=$APP_SRC"
        return
    fi

    echo "load to zk for reg :$INSTALLER_HOME/sbin/installer zkctl -c imp -p $appName"
    $INSTALLER_HOME/sbin/installer zkctl -c imp -p $appName
    #判断是否安装
    installHosts="`$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode/app/$appName|jq '.installHost'`"
    if [ "`echo "$installHosts" |wc -l `" -gt 2 ] ; then
        $INSTALLER_HOME/sbin/installer zkctl -c addappver -p $appName -v $appVersion
        echo "$appName installed ,build install package success and add version to zk"
    else
        echo "$appName not installed ,build install package success"
    fi
else
    echo "installer not installed ,build install package success :$appName/$appVerDir.tar.gz "
fi
}






