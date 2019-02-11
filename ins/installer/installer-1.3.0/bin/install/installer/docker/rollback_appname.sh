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
APP_HOME=`cd "$bin">/dev/null; pwd`
cd $APP_HOME 

envFile="/etc/profile.d/${APP_NAME}.sh"
sed -i -e "s/$_VERSION/$_FROM_VERSION/"  $envFile

if [ "`docker ps -a |grep ${APP_NAME} `" != "" ] ; then
    docker stop $(docker ps -a |grep ${APP_NAME}|awk '{print $1}')
    docker rm -f $(docker ps -a |grep ${APP_NAME}|awk '{print $1}')
fi

if [ "`docker images |grep \"${APP_NAME}:$_VERSION\" `" != "" ] ; then
	docker rmi -f ${APP_NAME}:$_VERSION
	echo "${APP_NAME} docker imagefile deleted."
fi
docker images |grep ${APP_NAME}

_DOCKER_TAG_NAME="${APP_NAME}-$_LOCALHOSTNAME"
 
INSTALL_DIR=`dirname "${bin}"`
INSTALL_DIR=$INSTALL_DIR/install 

installFile="$INSTALL_DIR/${APP_NAME}/${APP_NAME}-${_FROM_VERSION}-run.sh"

$installFile

echo "$_LOCALIP  $_LOCALHOSTNAME ${APP_NAME} rollback to $4 !"
