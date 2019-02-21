#!/bin/bash
#

export _LOCALIP=$1
export _LOCALHOSTNAME=$2
export _APP_VERSION=$3
if [ $# -lt 3 ] ; then 
  echo "usetag: localip localhostname appver "
  exit 1
fi
. ${APP_BASE}/install/funs.sh
bin=`dirname "${BASH_SOURCE-$0}"`
cd "$bin"
bin=`cd "$bin">/dev/null; pwd`
export APP_HOME="$bin"

export _APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
export appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
export APPNAME=`toupper "${appName}" `
confFile="$APP_HOME/conf/${appName}-install.conf"

export thisapp_datadir=`cat $confFile|grep "${appName}.datadir="|sed -e "s|${appName}.datadir=||"`
export thisapp_logdir=`cat $confFile|grep "${appName}.logdir="|sed -e "s|${appName}.logdir=||"`
export thisapp_port=`cat $confFile|grep "defaultPort="|sed -e "s|defaultPort=||"`
export thisapp_imagefile="${appName}-${_APP_VERSION}.tar.gz"

if [ "$thisapp_datadir" = "" ] ; then
    export thisapp_datadir="${DATA_BASE}/${appName}"
fi
if [ "$thisapp_logdir" = "" ] ; then
    export thisapp_logdir="${LOGS_BASE}/${appName}"
fi

if [ ! -f "${APP_HOME}/${thisapp_imagefile}" ]; then 
	echo "镜像文件不存在: ${APP_HOME}/${thisapp_imagefile}"
	exit 1
fi
if [ "$thisapp_port" = "" ] ; then
   echo "config is null "
  exit 1
fi

hvieAutoShFlag=` ps -ef|grep hive_auto_start.sh |grep -v grep |wc -l `

if [ "$hvieAutoShFlag" = "1" ] ; then
    /bin/stop_hive_autostart.sh
fi
mkdir /etc/mysql/conf.d -p
SUDO=""
if [ "$USER" != "root" ] ; then
SUDO="sudo"
fi

$SUDO rm -rf $thisapp_datadir/*
mkdir -p $thisapp_datadir
chmod 1777 -R $thisapp_datadir

$SUDO rm -rf $thisapp_logdir
mkdir -p $thisapp_logdir
chmod 1777 -R $thisapp_logdir

echo "docker rmi ${appName}:$_APP_VERSION imagefile..."

dockerImages=$(docker ps -a |grep "${appName}:${_APP_VERSION}"| awk '{printf("%s "),$1}')
if [ "$dockerImages" != "" ] ; then
for CT in $dockerImages ; do
    docker rm -f $CT
done
fi

needLoadImage=true
dockerImages=$(docker images |awk '{printf("%s:%s\n",$1,$2);}'| grep -v "REPOSITORY:TAG" |grep "${appName}:${_APP_VERSION}" )
if [ "$dockerImages" != "" ] ; then
    for CT in $dockerImages ; do
        if [ "$CT" = "${appName}:${_APP_VERSION}" ] ; then
            needLoadImage=false
        else
            docker rmi -f  $CT
        fi 
    done
fi

if [ "$needLoadImage" = "true" ] ; then
   echo "loading ${appName}${_APP_VERSION} docker imagefile...
gunzip -c $APP_HOME/$thisapp_imagefile | docker load   "
gunzip -c $APP_HOME/$thisapp_imagefile | docker load  
else
   echo "image ${appName}:${_APP_VERSION} exist, skip load imagefile"
fi 

# docker images |grep ${appName}

echo "${appName} docker imagefile loaded."


"$bin"/install_${appName}_galera.sh

RES=$?

if [ "$hvieAutoShFlag" = "1" ] ; then
    /bin/start_hive_autostart.sh
fi

echo "APP_HOME docker install finished." 
exit $RES
