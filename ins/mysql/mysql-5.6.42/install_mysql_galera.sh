#!/bin/bash
#

echo "start install ${appName}..."
. /etc/bashrc

IS_UPGRADE=$1

echo "IS_UPGRADE=$IS_UPGRADE"
_CONF_DIR="${APP_HOME}/conf"

chmod -R 644 ${_CONF_DIR}/my.cnf  # 所有cnf不能赋权为777，否则会导致mysql因为安全策略的原因被忽略。
chmod -R 644 ${_CONF_DIR}/conf.d
#my.cnf

#将run命令写入指定的路径中
INSTALL_DIR=`dirname "${APP_HOME}"`
INSTALL_DIR=$INSTALL_DIR/install 
mkdir -p  $INSTALL_DIR/${appName}
installFile="$INSTALL_DIR/${appName}/${appName}-${_APP_VERSION}-run.sh"
DOCKER_TAG_NAME="${appName}"

echo "#!/bin/bash 
. /etc/bashrc
. \${APP_BASE}/install/funs.sh
checkRunUser ${appName}
 docker run --name=${appName} --net=host \$DOCKER_OTHER_PARAMS \$${APPNAME}_RESOURCES  --privileged=true \
 -v ${_CONF_DIR}:/etc/mysql -v $thisapp_datadir:/var/lib/mysql -v $thisapp_logdir:/var/log/mysql \
 -v ${_CONF_DIR}/mysqld.sh:/mysqld.sh  -v /etc/localtime:/etc/localtime:ro -d ${appName}:${_APP_VERSION}" >$installFile

chmod +x $installFile
oldMysql=`docker ps -a|grep "$DOCKER_TAG_NAME"|wc -l `
if [ "$oldMysql" -gt "0" ] ; then
    docker stop   $DOCKER_TAG_NAME
    docker rm -f $DOCKER_TAG_NAME
fi

cat $installFile

RETRY_NUM=0
while [ 1 ] ;  do
    $installFile
    echo "sleep 2"
    sleep 2
    size=`docker ps |grep $DOCKER_TAG_NAME |wc -l `
    if [[ "$size" -gt 0 ]] ; then 
       break;
    fi
    ((RETRY_NUM++))
    if [[ $RETRY_NUM -gt 5 ]] ; then
        exit 1
    fi
done

sleep 5
MYCLI_NAME="mysql"

RETRY_RUN_NUM=0
RETRY_NUM=0
while [ 1 ] ;  do
    if [ -z "`docker ps | grep $DOCKER_TAG_NAME`" ];then
        echo "$DOCKER_TAG_NAME not running"
        ((RETRY_RUN_NUM++))
        if [ "$RETRY_RUN_NUM" -lt "2" ] ; then
            docker start $DOCKER_TAG_NAME
        else
            exit 1
        fi
    fi
    echo "Try $RETRY_NUM times : docker exec ${DOCKER_TAG_NAME} $MYCLI_NAME  -N -e \"show status  WHERE variable_name  LIKE 'wsrep_ready' OR variable_name LIKE 'wsrep_cluster_size' \""
    ALL_OUT=$(docker exec ${DOCKER_TAG_NAME} $MYCLI_NAME  -N -e "show status  WHERE variable_name  LIKE 'wsrep_ready' OR variable_name LIKE 'wsrep_cluster_size' " 2>/dev/null)
    if [ "$ALL_OUT" != "" ] ; then
        echo "ALL_OUT=$ALL_OUT"
        break
    fi
    sleep 5
    ((RETRY_NUM++))
    if [[ $RETRY_NUM -gt 20 ]] ; then
        tail $LOGS_BASE/${appName}/mysql.err -n 5  
        if [ "$IS_UPGRADE" != "true" -o $RETRY_NUM -gt 200 ] ; then
            exit 1
        fi
    fi
done


if [ "$IS_UPGRADE" != "true" ] ; then
    echo "docker stop $DOCKER_TAG_NAME"
    docker stop "$DOCKER_TAG_NAME"
else
    echo "need not stop ${appName}"    
fi

#需将安装完成后的docker name用于构建docker start/stop命令
#存到start_${appName}.sh中
_START_DB_FILE="${APP_HOME}/sbin/start_${appName}.sh"
rm -f $_START_DB_FILE
touch $_START_DB_FILE
echo "#!/bin/bash
. \$APP_BASE/install/funs.sh
if [ \"\$1\" != \"\" ] ; then
    hostId=0
    for HOST in \${${appName}_hosts//,/ } ; do
        if [ "\$HOST" = "\$HOSTNAME" ] ; then
            break
        fi
        ((hostId++))
    done
    for ((i=0; i <hostId;i++ )) do
        echo "sleep 10s for wait other host start"
        sleep 10
    done
fi
if [ -f \"${APP_HOME}/sbin/auto_start.sh.bak\" ] ; then
    mv ${APP_HOME}/sbin/auto_start.sh.bak ${APP_HOME}/sbin/auto_start.sh
fi
echo \"START_TIME=\`date \"+%s\"\`\" > $LOGS_BASE/${appName}/check_tmp.log
beginErrLog
docker start ${appName}
writeOptLog

"> $_START_DB_FILE

chmod a+x $_START_DB_FILE

_STOP_DB_FILE="${APP_HOME}/sbin/stop_${appName}.sh"
rm -f $_STOP_DB_FILE
touch $_STOP_DB_FILE
echo "#!/bin/bash
. \$APP_BASE/install/funs.sh
if [ -f \"${APP_HOME}/sbin/auto_start.sh\" ] ; then
    mv ${APP_HOME}/sbin/auto_start.sh ${APP_HOME}/sbin/auto_start.sh.bak
fi
beginErrLog
docker stop ${appName}
writeOptLog

">$_STOP_DB_FILE

chmod a+x $_STOP_DB_FILE

exit 0

