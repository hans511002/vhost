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

registryImage=`docker images |grep "${APP_NAME}:$_VERSION"|awk '{printf("%s:%s ",$1,$2)}'`
if [ "$registryImage" != "" ] ; then
    docker rmi -f $registryImage
    echo "${APP_NAME} docker image deleted $registryImage ."
fi
docker images |grep ${APP_NAME}
if [ "`docker ps -a |grep ${APP_NAME} `" != "" ] ; then
    docker stop $(docker ps -a |grep ${APP_NAME}|awk '{print $1}')
    docker rm -f $(docker ps -a |grep ${APP_NAME}|awk '{print $1}')
fi
res=1
while(( $int<=5 )) ;  do
    sleep 3
    let "int++"
    consize=`docker ps|grep "$REGISTRY_DOMAIN:5000/${APP_NAME}:latest" | wc -l `
    if [ "$consize" -ne "1" ] ; then
        continue
    fi
    res=0
    break
done
if [ "$res" = "0" ] ; then
    echo "$_LOCALIP  $_LOCALHOSTNAME ${APP_NAME} rollback to $4 !"
else
    echo "$_LOCALIP  $_LOCALHOSTNAME ${APP_NAME} rollback to $4 failed !"
fi
