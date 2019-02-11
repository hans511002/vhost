#!/bin/bash
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ "$INSTALLER_HOME" = "" -o "${installer_hosts}" = "" ] ; then
    echo "not install deploy app : installer"
    exit 1
fi
if [ "$USER" != "root" ] ; then
    echo "must run in root user : setNewLogDb.sh true"
    exit 1
fi

if [ "$#" -lt "1" ] ; then
    echo "copyDb.sh newdbname"
    exit 1
fi
paasLogApp="$1"

. ${APP_BASE}/install/funs.sh
ZKBaseNode=`getDeployZkNode`
deployGobalConfig=`$INSTALLER_HOME/sbin/installer zkctl -c get -p $ZKBaseNode/gobal`
APP_SRC=`echo "$deployGobalConfig" | jq  '.APP_SRC' `
APP_SRC=${APP_SRC//\"/}
echo "APP_SRC=$APP_SRC"
srcDbApp="mysqlcopy"
paasLogAppDir="$APP_SRC/$paasLogApp"
if [ "$2" = "true" ] ; then
    rm -rf $paasLogAppDir
fi
if [ ! -e "$APP_SRC/$srcDbApp" ] ; then
    echo "dir $APP_SRC/$srcDbApp not exists"
    exit 1
fi

if [ ! -d "$paasLogAppDir" ] ; then
    rm -rf "$paasLogAppDir"
    echo "cp -rp $APP_SRC/$srcDbApp $paasLogAppDir"
    cp -rp $APP_SRC/$srcDbApp $paasLogAppDir
    echo "cd $paasLogAppDir"
    cd $paasLogAppDir
    
    srcPackage=`ls $srcDbApp-*.tar.gz |sort -V `
    echo "srcPackage=$srcPackage"
    dbVer=`echo "$srcPackage" | sed -e "s|$srcDbApp-\(.*\).tar.gz|\1|"`
    echo "mv $srcPackage $paasLogApp-$dbVer.tar.gz "
    mv $srcPackage $paasLogApp-$dbVer.tar.gz 
    if [ -f "$srcDbApp.json" ] ; then
        echo "mv $srcDbApp.json $paasLogApp.json"
        mv $srcDbApp.json $paasLogApp.json
        echo "sed -i -e \"s|$srcDbApp|$paasLogApp|g\" $APP_SRC/$paasLogApp/$paasLogApp.json"
        sed -i -e "s|$srcDbApp|$paasLogApp|g" $APP_SRC/$paasLogApp/$paasLogApp.json
    else
        echo "$INSTALLER_HOME/sbin/installer zkctl -c exp"
        $INSTALLER_HOME/sbin/installer zkctl -c exp
        if [ -f "$APP_SRC/$srcDbApp/$srcDbApp.json" ] ; then
            echo "scp -rp $APP_SRC/$srcDbApp/$srcDbApp.json $APP_SRC/$paasLogApp/$paasLogApp.json"
            scp -rp $APP_SRC/$srcDbApp/$srcDbApp.json $APP_SRC/$paasLogApp/$paasLogApp.json
            echo "sed -i -e \"s|$srcDbApp|$paasLogApp|g\" $APP_SRC/$paasLogApp/$paasLogApp.json"
            sed -i -e "s|$srcDbApp|$paasLogApp|g" $APP_SRC/$paasLogApp/$paasLogApp.json
        else
            echo "scp -rp $APP_SRC/mysql/mysql.json $APP_SRC/$paasLogApp/$paasLogApp.json"
            scp -rp $APP_SRC/mysql/mysql.json $APP_SRC/$paasLogApp/$paasLogApp.json
            echo "scp -rp $APP_SRC/mysql/mysql.json $APP_SRC/$srcDbApp/$srcDbApp.json"
            scp -rp $APP_SRC/mysql/mysql.json $APP_SRC/$srcDbApp/$srcDbApp.json
            echo "sed -i -e \"s|mysql|$srcDbApp|g\" $APP_SRC/$srcDbApp/$srcDbApp.json"
            sed -i -e "s|mysql|$srcDbApp|g" $APP_SRC/$srcDbApp/$srcDbApp.json
            echo "sed -i -e \"s|mysql|$paasLogApp|g\" $APP_SRC/$paasLogApp/$paasLogApp.json"
            sed -i -e "s|mysql|$paasLogApp|g" $APP_SRC/$paasLogApp/$paasLogApp.json
        fi
    fi
    logdbConfigJson=`cat $APP_SRC/$paasLogApp/$paasLogApp.json`
    logdbConfigJson=`echo "$logdbConfigJson" | jq 'setpath(["app","copyFrom"]; "'$srcDbApp'") '`
    echo "$logdbConfigJson" > $APP_SRC/$paasLogApp/$paasLogApp.json
    for file in `ls $srcPackage*` ; do
        echo "rm -rf $file"
        rm -rf $file
    done
    echo "tar xf $paasLogApp-$dbVer.tar.gz"
    tar xf $paasLogApp-$dbVer.tar.gz
    echo "mv $srcDbApp-$dbVer $paasLogApp-$dbVer"
    mv $srcDbApp-$dbVer $paasLogApp-$dbVer
    echo "cd $paasLogAppDir/$paasLogApp-$dbVer"
    cd $paasLogAppDir/$paasLogApp-$dbVer
    find ./ -name "*"|grep $srcDbApp |awk '{printf("%s %s\n",$1,$1)}' | sed -e "s|$srcDbApp|$paasLogApp|" | awk '{printf("scp -rp %s %s && rm -rf %s \n",$2,$1,$2)}' 
    find ./ -name "*"|grep $srcDbApp |awk '{printf("%s %s\n",$1,$1)}' | sed -e "s|$srcDbApp|$paasLogApp|" | awk '{printf("scp -rp %s %s && rm -rf %s \n",$2,$1,$2)}' | sh
    
    echo "gunzip -c $paasLogApp-$dbVer.tar.gz |docker load "
    gunzip -c $paasLogApp-$dbVer.tar.gz |docker load 
    echo "docker tag $srcDbApp-$dbVer $paasLogApp-$dbVer"
    docker tag $srcDbApp:$dbVer $paasLogApp:$dbVer
    echo "docker save -o $paasLogApp-$dbVer.tar $paasLogApp:$dbVer"
    docker save -o $paasLogApp-$dbVer.tar $paasLogApp:$dbVer
    echo "rm -rf $paasLogApp-$dbVer.tar.gz"
    rm -rf $paasLogApp-$dbVer.tar.gz
    echo "gzip $paasLogApp-$dbVer.tar"
    gzip $paasLogApp-$dbVer.tar
    echo "cd $paasLogAppDir"
    cd $paasLogAppDir 
    tar zcf $paasLogApp-$dbVer.tar.gz $paasLogApp-$dbVer
    if [ -f "$APP_SRC/clean_app_info.sh" ] ; then
        echo "$APP_SRC/clean_app_info.sh   beging .........." 
        $APP_SRC/clean_app_info.sh 
        echo "$APP_SRC/clean_app_info.sh   end ............ "
    fi
    echo "$INSTALLER_HOME/sbin/installer zkctl -c imp"
    $INSTALLER_HOME/sbin/installer zkctl -c imp
fi
