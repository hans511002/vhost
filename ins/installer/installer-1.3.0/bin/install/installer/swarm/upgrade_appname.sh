#!/bin/bash 
#desc:installer auto build
. /etc/bashrc

if [ $# -lt 4 ] ; then 
  echo "usetag: localip localhostname appver fromVer "
  exit 1
fi

export _LOCALIP=$1
export _LOCALHOSTNAME=$2
export _VERSION=$3
export _FROM_VERSION=${4}
echo "_VERSION=$_VERSION"

APP_HOME=`dirname "${BASH_SOURCE-$0}"`
APP_HOME=`cd "$APP_HOME">/dev/null; pwd`
cd $APP_HOME

CFG_FILE="$APP_HOME/conf/${APP_NAME}_install.conf"
if [ ! -f "$CFG_FILE" ]; then 
	echo "config file not exists: ${CFG_FILE}"
	exit 1
fi 
if [ ! -f "${APP_HOME}/${IMAGE_TAG_NAME}-$_VERSION.tar.gz" ]; then 
	echo "image file not exists: ${APP_HOME}/${IMAGE_TAG_NAME}-$_VERSION.tar.gz"
	exit 1
fi

${APP_HOME}/start_install_${APP_NAME}.sh  ${_LOCALIP} ${_LOCALHOSTNAME} ${_VERSION} 
res=$?
if [ "$res" = "0" ] ; then
    echo "${START_SHELL}"
    ${START_SHELL}
    echo "${CHECK_SHELL}"
    ${CHECK_SHELL}
    res=$?
fi

reservSize=3
allVerSize=`find ${APP_BASE} -maxdepth 1 -type d | grep -v "^${APP_BASE}$" | awk -F '/' '{print $NF}' | grep "^${APP_NAME}-[0-9]\.[0-9]\.[0-9]*[0-9]$" | wc -l`
if [ "$allVerSize" -gt "$reservSize" ] ; then
    allVers=`find ${APP_BASE} -maxdepth 1 -type d | grep -v "^${APP_BASE}$" | awk -F '/' '{print $NF}' | grep "^${APP_NAME}-[0-9]\.[0-9]\.[0-9]*[0-9]$"`
    resvVers=`find ${APP_BASE} -maxdepth 1 -type d | grep -v "^${APP_BASE}$" | awk -F '/' '{print $NF}' | grep "^${APP_NAME}-[0-9]\.[0-9]\.[0-9]*[0-9]$" | sort | tail -n $reservSize`
    resvVers="$resvVers"
    for APPVER in $allVers ; do
        if [ "${resvVers//$APPVER/}" != "${resvVers}" ] ; then
            continue
        fi
        appName=`echo $APPVER | sed -e 's|-.*||'`
        appVer=`echo $APPVER | sed -e 's|-.*||'`

        appIms=`docker images|grep ${APP_NAME}|wc -l`
        if [ "$appIms" -gt "1" ] ; then
            appImage=`docker images|grep ${APP_NAME}|grep $appVer|awk '{printf("%s:%s", $1,$2}'` 
            if [ "${appImage//$appName:$appVer/}" != "${appImage}" ] ; then
                echo "drop images: docker rmi -f $appImage"
                docker rmi -f $appImage
            fi
        fi
        echo "delete file: rm -rf ${APP_BASE}/$APPVER"
        rm -rf ${APP_BASE}/$APPVER
    done
fi

if [ "$res" = "0" ] ; then
    echo "$_LOCALIP  $_LOCALHOSTNAME  ${APP_NAME} upgrade from $_FROM_VERSION to $_VERSION success"
else
    echo "$_LOCALIP  $_LOCALHOSTNAME  ${APP_NAME} upgrade from $_FROM_VERSION to $_VERSION failed "
fi
exit $res
