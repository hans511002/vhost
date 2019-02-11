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

export appName=${APP_NAME}

if [ -f $APP_HOME/mysql/initMysql.sh ] ; then
    echo "first upgrade database "
    $APP_HOME/mysql/initMysql.sh $_LOCALIP $_LOCALHOSTNAME $_VERSION $_FROM_VERSION
    if [ "$?" != "0" ] ; then
       exit 1
    fi
fi
if [ -f $APP_HOME/mongo/initMongo.sh ] ; then
    echo "first upgrade database "
    $APP_HOME/mongo/initMongo.sh $_LOCALIP $_LOCALHOSTNAME $_VERSION $_FROM_VERSION
    if [ "$?" != "0" ] ; then
       exit 1
    fi
fi

# load images and push to registry
echo "loading ${APP_NAME} docker imagefile..${APP_HOME}/${APP_NAME}-${_VERSION}.tar.gz "
if [ ! -e "${APP_HOME}/${APP_NAME}-${_VERSION}.tar.gz" ]; then
	echo "image file not exists: ${APP_HOME}/${APP_NAME}-${_VERSION}.tar.gz"
	exit 1
fi
echo "load images begin ------gunzip -c $APP_HOME/${APP_NAME}-${_VERSION}.tar.gz |docker load "
gunzip -c ${APP_HOME}/${APP_NAME}-${_VERSION}.tar.gz |docker load
echo "${APP_NAME} docker imagefile loaded."
echo "docker tag ${APP_NAME}:${_VERSION} $REGISTRY_DOMAIN:5000/${APP_NAME}:${_VERSION} "
docker tag ${APP_NAME}:${_VERSION} $REGISTRY_DOMAIN:5000/${APP_NAME}:${_VERSION}
echo "docker tag ${APP_NAME}:${_VERSION} $REGISTRY_DOMAIN:5000/${APP_NAME}:latest "
docker tag ${APP_NAME}:${_VERSION} $REGISTRY_DOMAIN:5000/${APP_NAME}:latest
echo "docker rmi ${APP_NAME}:${_VERSION}"
echo "docker push $REGISTRY_DOMAIN:5000/${APP_NAME}:${_VERSION}"
docker push $REGISTRY_DOMAIN:5000/${APP_NAME}:${_VERSION}
errorExit $? "docker push failed"
echo "docker push $REGISTRY_DOMAIN:5000/${APP_NAME}:latest "
docker push $REGISTRY_DOMAIN:5000/${APP_NAME}:latest
errorExit $? "docker push failed"
registryImage=`docker images |grep $REGISTRY_DOMAIN:5000/${APP_NAME}|awk '{printf("%s:%s ",$1,$2)}'`
if [ "$registryImage" = "${registryImage/$REGISTRY_DOMAIN:5000\/${APP_NAME}:latest/}" ] ; then
	errorExit 1  "download images from $REGISTRY_DOMAIN:5000 failed "
fi

echo ""> $${APPNAME}_HOME/conf/.upservers
for HOST in `cat $${APPNAME}_HOME/conf/servers`; do
	_LOCALIP=`ping -c 1 $HOST |grep "$HOST" |grep "bytes from" |sed -e 's/.*bytes from//' -e 's/:.*//' -e 's/.*(//' -e 's/).*//'`
	_LOCALHOSTNAME="$HOST"
	echo "$HOST" >> $${APPNAME}_HOME/conf/.upservers
    echo "  upgrade ${APP_NAME} on  $HOST ,use shell: $APP_HOME/upgrade_${APP_NAME}.sh $_LOCALIP  $_LOCALHOSTNAME $_VERSION $_FROM_VERSION "
	ssh $HOST $APP_HOME/upgrade_${APP_NAME}.sh $_LOCALIP  $_LOCALHOSTNAME $_VERSION $_FROM_VERSION
	if [ "$?" != "0" ] ; then
			echo "host $HOST ${APP_NAME} upgrad from $_FROM_VERSION to $_VERSION failed"
	   exit 1
	fi
done

exit 0
