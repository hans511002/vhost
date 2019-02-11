#! /usr/bin/env bash
#
if [ $# -lt 4 ] ; then
	echo APP_BASE ZOO_CFG HOST_NAME APP_SRC
	exit 1
fi

APP_BASE=$1
ZOO_CFG=$2
HOST_NAME=$3
APP_SRC=$4

if [ $# -lt 4 ] ; then
    echo "APP_BASE ZOO_CFG HOST_NAME APP_SRC "
	exit 1
fi


ADD_HOSTS=$6

hostIds=$(grep "^[[:space:]]*server.*=" "$ZOO_CFG" | sed -e 's/.*\.//' | sed -e 's/:.*//')
DATA_DIR=$(grep "^[[:space:]]*dataDir.*=" "$ZOO_CFG" | sed -e 's/dataDir.*=//' | sed -e 's/ //')
LOGS_DIR=$(grep "^[[:space:]]*dataLogDir.*=" "$ZOO_CFG" | sed -e 's/dataLogDir=//' )
CLIENT_PORT=$(grep "^[[:space:]]*clientPort.*=" "$ZOO_CFG" | sed -e 's/clientPort.*=//'  | sed -e 's/ //')
sed -i -e "s|dataLogDir=.*|dataLogDir=$DATA_DIR|" $ZOO_CFG

if [ -z "$hostIds" -o -z "$DATA_DIR" -o -z "$LOGS_DIR" -o -z "CLIENT_PORT" ]; then
    echo "$ZOO_CFG: check failed!"
    exit 1
fi

echo DATA_DIR=$DATA_DIR
echo LOGS_DIR=$LOGS_DIR

jps|grep QuorumPeerMain|awk '{print $1}'|xargs kill -9 

echo "mkdir -p $DATA_DIR"
mkdir -p $DATA_DIR
echo "mkdir -p $LOGS_DIR"
mkdir -p $LOGS_DIR
echo "clean zk data "
rm -rf  $DATA_DIR/*

HOST_ID=
HOST_CLS_PORT=
HOST_MAG_PORT=
ZOOKEEPER_URL=,
for host in $hostIds; do
 HID=(${host//=/ })
   ZOOKEEPER_URL="$ZOOKEEPER_URL,${HID[1]}:$CLIENT_PORT"
done
echo ZOOKEEPER_URL=$ZOOKEEPER_URL
ZOOKEEPER_URL=${ZOOKEEPER_URL//,,/}


CLS_HOST_LIST=`cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'`
FISRTHOST=`echo $CLS_HOST_LIST|awk '{print $1}'`
#À©ÈÝ°²×°
if [ "$ADD_HOSTS" != "" ] ; then
    ADD_HOSTS=${ADD_HOSTS//,/ }
    FISRTHOST=`echo $ADD_HOSTS|awk '{print $1}'`
fi

echo "export KEEP_SNAPSLOGS_COUNT=100 ">>/etc/profile.d/zookeeper.sh 
echo "export ZOO_LOG_DIR=\"$LOGS_DIR\" ">>/etc/profile.d/zookeeper.sh 

for HOST in $CLS_HOST_LIST ; do
	ssh $HOST "echo 'export ZOOKEEPER_URL=\"$ZOOKEEPER_URL\"'>>/etc/profile.d/zookeeper.sh"
done


#
#if [ "$FISRTHOST" = "$HOSTNAME" ] ; then   
#    for HOST in $CLS_HOST_LIST ; do
##        ssh $HOST "sed -i -e 's/export ZOOKEEPER_HOME=.*//' /etc/bashrc " 
##        ssh $HOST "sed -i -e 's/.*ZOOKEEPER_HOME\/sbin//' /etc/bashrc " 
#
#        ssh $HOST "sed -i -e 's/export ZOOKEEPER_URL=.*//' /etc/bashrc " 
#        ssh $HOST "sed -i -e 's/export ZOO_LOG_DIR=.*//' /etc/bashrc " 
#        ssh $HOST "echo \"export ZOOKEEPER_URL=$ZOOKEEPER_URL\">>/etc/bashrc "  
#        if [ "${ZOOKEEPER_URL//$host/}" != "$ZOOKEEPER_URL" ] ; then
#            ssh $HOST "echo \"export ZOO_LOG_DIR=$LOGS_DIR\">>/etc/bashrc "  
#        fi
#    done
# fi
##sed -i -e 's/export ZOOKEEPER_URL=*//' /etc/bashrc
##sed -i -e 's/export ZOO_LOG_DIR=*//' /etc/bashrc
##
##echo "export ZOOKEEPER_URL=$ZOOKEEPER_URL 
##export ZOO_LOG_DIR=$LOGS_DIR
##">> /etc/bashrc
#


appDir=`dirname $APP_SRC`
appNameVer=${APP_SRC//\.tar.*/}
appNameVer=${appNameVer//$appDir\//}
appNameVer=${appNameVer//.*\//}

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

RES=$?
if [ ! $RES -eq 0 ] ; then  
exit $RES
fi
cd ${APP_BASE} ; tar -xf ${APP_SRC}

exit $?
