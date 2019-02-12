#! /usr/bin/env bash
#
# author: zyg
# description: 
#
#docker run --rm -ti -v ${APP_BASE}/zookeeper-3.4.6:${APP_BASE}/zookeeper-3.4.6 -v \
#${DATA_BASE}/data/zookeeper:${DATA_BASE}/data/zookeeper  -v ${LOGS_BASE}/logs/zookeeper:${LOGS_BASE}/logs/zookeeper --net=host 
#centos-jdk:1.8.0 ${APP_BASE}/zookeeper-3.4.6/bin/zkServer.sh start-foreground
#

if [ $# -lt 3 ] ; then
	echo HOST_NAME APP_NAME APP_VERSION
	exit 1
fi

HOST_NAME=$1
APP_NAME=$2
APP_VERSION=$3
ADD_HOSTS=$5
APP_HOME=${APP_BASE}/$APP_NAME-${APP_VERSION}
ZOO_CFG=$APP_HOME/conf/zoo.cfg

hostIds=$(grep "^[[:space:]]*server.*=" "$ZOO_CFG" | sed -e 's/.*\.//' | sed -e 's/:.*//g')
DATA_DIR=$(grep "^[[:space:]]*dataDir.*=" "$ZOO_CFG" | sed -e 's/dataDir=//' -e 's/ //g')
LOGS_DIR=$(grep "^[[:space:]]*dataLogDir.*=" "$ZOO_CFG" | sed -e 's/dataLogDir=//' -e 's/ //g')
CLIENT_PORT=$(grep "^[[:space:]]*clientPort.*=" "$ZOO_CFG" | sed -e 's/clientPort.*=//'  | sed -e 's/ //g')
sed -i -e "s|dataLogDir=.*|dataLogDir=$DATA_DIR|" $ZOO_CFG

if [ -z "$hostIds" -o -z "$DATA_DIR" -o -z "$LOGS_DIR" -o -z "CLIENT_PORT" ]; then
    echo "$ZOO_CFG: check failed!"
    exit 1
fi

echo DATA_DIR=$DATA_DIR
echo LOGS_DIR=$LOGS_DIR

echo "mkdir -p $DATA_DIR"
mkdir -p $DATA_DIR
echo "mkdir -p $LOGS_DIR"
mkdir -p $LOGS_DIR


HOST_ID=
HOST_CLS_PORT=
HOST_MAG_PORT=
ZOOKEEPER_URL=,
for host in $hostIds; do
 HID=(${host//=/ })
   ZOOKEEPER_URL="$ZOOKEEPER_URL,${HID[1]}:$CLIENT_PORT"
done
ZOOKEEPER_URL=${ZOOKEEPER_URL//,,/}
echo ZOOKEEPER_URL=$ZOOKEEPER_URL

FISRTHOST=`echo $CLUSTER_HOST_LIST|awk '{print $1}'`
#À©ÈÝ°²×°
if [ "$ADD_HOSTS" != "" ] ; then
    ADD_HOSTS=${ADD_HOSTS//,/ }
    FISRTHOST=`echo $ADD_HOSTS|awk '{print $1}'`
fi

echo "export KEEP_SNAPSLOGS_COUNT=100 ">>/etc/profile.d/$APP_NAME.sh 
echo "export ZOO_LOG_DIR=\"$LOGS_DIR\" ">>/etc/profile.d/$APP_NAME.sh 

for HOST in $CLUSTER_HOST_LIST ; do
	ssh $HOST "echo 'export ZOOKEEPER_URL=\"$ZOOKEEPER_URL\"'>>/etc/profile.d/$APP_NAME.sh"
done

for zookeeper in $hostIds; do
    HID=(${zookeeper//=/ })
    if [ "X$HOST_NAME" = "X${HID[1]}" ] ; then
         HOST_ID=${HID[0]}
         HOST_CLS_PORT=$(grep "^[[:space:]]*server.$zookeeper" "$ZOO_CFG" | sed -e 's/.*'$zookeeper'\://')
         HPS=(${HOST_CLS_PORT//:/ })
         HOST_CLS_PORT=${HPS[0]}
         HOST_MAG_PORT=${HPS[1]}
         break
    fi
done

echo HOST_CLS_PORT=$HOST_CLS_PORT
echo HOST_MAG_PORT=$HOST_MAG_PORT

echo HOST_NAME=$HOST_NAME HOST_ID=$HOST_ID
echo "$HOST_ID" > $DATA_DIR/myid

useDocker=false
dockImgs=`docker images`
if [ "$?" = "0" ] ; then
    dockImgs=`echo "$dockImgs"|grep -v IMAGE|awk '{printf("%s:%s\n",$1,$2)}'|grep "jdk:1."|sort -V |tail -n 1`
    if [ "$dockImgs" != "" ] ; then
        useDocker=true
    fi 
fi 
echo dockImgs="$dockImgs"

if [ "$useDocker" != "true" ] ; then
    jps|grep QuorumPeerMain|awk '{print $1}'|xargs kill -9 2>/dev/null
    echo "#!/bin/bash
. /etc/bashrc
. \$APP_BASE/install/funs.sh

appHome=\$(dirname \$(cd \$(dirname \$0); pwd))
appName=\$(echo \${appHome##*/} | awk -F '-' '{print \$1}' )
if [ \"\$1\" = \"restart\" ] ; then
   \$ZOOKEEPER_HOME/bin/zkServer.sh stop
fi 
\$ZOOKEEPER_HOME/bin/zkServer.sh start
">$APP_HOME/sbin/start_zookeeper.sh

echo "#!/bin/bash
. /etc/bashrc
. \$APP_BASE/install/funs.sh

appHome=\$(dirname \$(cd \$(dirname \$0); pwd))
appName=\$(echo \${appHome##*/} | awk -F '-' '{print \$1}')
\$ZOOKEEPER_HOME/bin/zkServer.sh stop 
">$APP_HOME/sbin/stop_zookeeper.sh

else
    runFile=${APP_BASE}/install/$APP_NAME/$APP_NAME-$APP_VERSION-run.sh 
    echo "#!/bin/bash
. /etc/bashrc
. \${APP_BASE}/install/funs.sh
checkRunUser ${APP_NAME}
docker run --name=$APP_NAME --network=host --privileged=true -v $APP_HOME:$APP_HOME -v $DATA_DIR:$DATA_DIR -v $LOGS_DIR:$LOGS_DIR \\
-d $dockImgs $APP_HOME/bin/zkServer.sh start-foreground
     " > ${runFile} 
     chmod +x $runFile
    docker stop $APP_NAME 2>/dev/null
    docker rm -f $APP_NAME 2>/dev/null
    cat $runFile
         
    RETRY_NUM=0
    while [ 1 ] ;  do
        $runFile
        echo "sleep 2"
        sleep 2
        size=`docker ps |awk '{printf("%s:%s\n",$2,$NF)}' |grep "^$dockImgs:$APP_NAME\$" |wc -l `
        if [[ "$size" -gt 0 ]] ; then
           break;
        fi
        ((RETRY_NUM++))
        if [[ $RETRY_NUM -gt 5 ]] ; then
            exit 1
        fi
        docker rm -f $APP_NAME 2>/dev/null
    done
    echo "sleep 5"
    sleep 5
    docker stop $APP_NAME 

    echo "#!/bin/bash
. /etc/bashrc
. \$APP_BASE/install/funs.sh
appHome=\$(dirname \$(cd \$(dirname \$0); pwd))
appName=\$(echo \${appHome##*/} | awk -F '-' '{print \$1}')
if [ \"\$1\" = \"restart\" ] ; then
    beginErrLog
    docker stop \${appName}
    writeOptLog
fi 
beginErrLog
docker start \${appName}
writeOptLog

">$APP_HOME/sbin/start_zookeeper.sh

echo "#!/bin/bash
. /etc/bashrc
. \$APP_BASE/install/funs.sh

appHome=\$(dirname \$(cd \$(dirname \$0); pwd))
appName=\$(echo \${appHome##*/} | awk -F '-' '{print \$1}')
beginErrLog
docker stop \${appName}
writeOptLog

">$APP_HOME/sbin/stop_zookeeper.sh

fi 

chmod +x $APP_HOME/sbin/start_zookeeper.sh $APP_HOME/sbin/stop_zookeeper.sh
