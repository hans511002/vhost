#!/bin/bash 
#desc:add galaxy conf to zk 

. /etc/bashrc
APP_HOME=`dirname "${BASH_SOURCE-$0}"`
APP_HOME=`cd "$APP_HOME">/dev/null; pwd`
cd $APP_HOME

if [ "$#" -lt "1" ] ; then
    echo "init_lb.sh lbfile lbName"
    exit 1
fi
fileName=$1
lbName=$2
if [ "$lbName" = "" ] ; then 
    _fileName=${fileName//*\//}
    echo _fileName=$_fileName
    lbName=`echo "$_fileName" |sed -e "s|.json||" -e "s|_|-|" ` 
fi

echo "load lbName=$lbName"
echo "load fileName=$fileName"

ROOT_PATH=`cat $INSTALLER_HOME/conf/installer.properties |grep "zk.base.node=" |sed -e 's|zk.base.node=||' `
CLUSTER_NAME=`cat $INSTALLER_HOME/conf/installer.properties |grep "cluster.name=" |sed -e 's|cluster.name=||' `
BASE_ZK_PATH="/$ROOT_PATH/$CLUSTER_NAME/loadbalance/services/$lbName"

echo "$INSTALLER_HOME/sbin/installer zkctl -c set -p $BASE_ZK_PATH -f $fileName"
$INSTALLER_HOME/sbin/installer zkctl -c set -p $BASE_ZK_PATH -f $fileName
if [ "$?" = "0" ] ; then
    echo "write $fileName config data success"
    $INSTALLER_HOME/sbin/installer zkctl -c get -p $BASE_ZK_PATH  
else
    echo "write $fileName config data failed"
    exit 1
fi
