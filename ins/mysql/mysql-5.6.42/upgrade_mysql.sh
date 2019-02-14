#!/bin/bash
 
export _LOCALIP=$1
export _LOCALHOSTNAME=$2
export _APP_VERSION=$3
export _FROM_VERSION=$4

if [ $# -lt 4 ] ; then 
  echo "usetag: localip localhostname appver _FROM_VERSION "
  exit 1
fi
. ${APP_BASE}/install/funs.sh 

bin=`dirname "${BASH_SOURCE-$0}"`
cd "$bin"
bin=`cd "$bin">/dev/null; pwd`
export APP_HOME="$bin"
export appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
export APPNAME=`toupper "${appName}" `
confFile="$APP_HOME/conf/${appName}-install.conf"

if [ ! -f "$confFile" ] ; then
    echo "defaultPort=3306
galeraPort=4567
galeraISTPort=4568
galeraSSTPort=4444
" > ./conf/$appName-install.conf
fi

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

modifyRootPassword(){

HIVE_USER='sobeyhive'
HIVE_PASSWORD='$0bEyHive&2o1Six'
ROOT_PASSWORD='$0BeyHive^2olSix'

appCTN=`docker ps -a|awk '/mysql-/{print $NF}'`
docker restart $appCTN
for i in {1..30};do
    echo "try $i times..."
    sleep 5
    res=`docker exec $appCTN mysql -e "show databases" >/dev/null 2>&1; echo $?`
    if [ "$res" = "0" ]; then
docker exec -i $appCTN mysql 2>/dev/null<<EOF
    #添加用户
    CREATE USER '$HIVE_USER'@'%' IDENTIFIED BY '$HIVE_PASSWORD';
    GRANT ALL ON *.* TO '$HIVE_USER'@'%' WITH grant OPTION;    
    
    #修改root密码
    use mysql;
    update user set password=password('$ROOT_PASSWORD') where user="root";    
EOF
        docker stop $appCTN
        return 0
    fi
    if [ "$i" = "15" ]; then
        echo "docker stop $appCTN"
        docker stop $appCTN
        echo "docker start $appCTN"
        docker start $appCTN
    fi
done
return 1
}

hvieAutoShFlag=` ps -ef|grep hive_auto_start.sh |grep -v grep |wc -l `

if [ "$hvieAutoShFlag" = "1" ] ; then
    /bin/stop_hive_autostart.sh
fi

SUDO=""
if [ "$USER" != "root" ] ; then
SUDO="sudo"
fi

#修改root密码(5.6.41修改一次即可)
if [ "$_APP_VERSION" = "5.6.41" ]; then
    modifyRootPassword || { echo "exec failed: modifyRootPassword"; exit 1; }
fi

echo "docker rmi ${appName}:$_APP_VERSION imagefile..."

# dockerImages=$(docker ps -a |grep "${appName}:${_APP_VERSION}"| awk '{printf("%s "),$NF}')
# if [ "$dockerImages" != "" ] ; then
# for CT in $dockerImages ; do
    # docker rm -f $CT
# done
# fi

appCTN=`docker ps -a|grep "${appName}:${_APP_VERSION}"|awk '/mysql-/{print $NF}'`
if [ "$appCTN" != "" ] ; then
    docker rm -f $appCTN
fi

# dockerImages=$(docker images |grep "${appName}:${_APP_VERSION}"| awk '{printf("%s "),$1}')
# if [ "$dockerImages" != "" ] ; then
# for CT in $dockerImages ; do
    # docker rmi -f  $CT
# done
# fi
echo "loading ${appName} docker imagefile...
gunzip -c $APP_HOME/$thisapp_imagefile | docker load   "
gunzip -c $APP_HOME/$thisapp_imagefile | docker load  

docker images |grep ${appName}

echo "${appName} docker imagefile loaded."

if [ "$hvieAutoShFlag" = "1" ] ; then
    /bin/stop_hive_autostart.sh
fi

#thisapp-5.6.28-run.sh 
mv ${APP_BASE}/install/${appName}/${appName}-${_FROM_VERSION}-run.sh  ${APP_BASE}/install/${appName}/${appName}-${_FROM_VERSION}-run.sh.bak
"$bin"/install_${appName}_galera.sh true
RES=$?
echo $APP_HOME/sbin/start_${appName}.sh 
$APP_HOME/sbin/start_${appName}.sh 
mv ${APP_BASE}/install/${appName}/${appName}-${_FROM_VERSION}-run.sh.bak  ${APP_BASE}/install/${appName}/${appName}-${_FROM_VERSION}-run.sh
 
if [ "$hvieAutoShFlag" = "1" ] ; then
    /bin/start_hive_autostart.sh
fi

#5.6.41升级后停止容器,用msyql集群命令起
if [ "$_APP_VERSION" = "5.6.41" ]; then
    echo $APP_HOME/sbin/stop_${appName}.sh 
    $APP_HOME/sbin/stop_${appName}.sh  
fi

echo "${appName} docker install finished." 
exit $RES







