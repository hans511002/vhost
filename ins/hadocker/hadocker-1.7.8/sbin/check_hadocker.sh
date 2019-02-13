#! /bin/bash
. /etc/bashrc

#获取当前目录
HAPROXY_APP_HOME=`dirname "${BASH_SOURCE-$0}"`
HAPROXY_APP_HOME=`dirname "${HAPROXY_APP_HOME}"`
HAPROXY_APP_HOME=`cd "$HAPROXY_HOME">/dev/null; pwd`
cd $HAPROXY_APP_HOME

HAPROXY_APP_NAME="hadocker"

dockerCons=`docker ps |grep dynamic-ha- |grep $HAPROXY_APP_NAME | awk '{print $NF}'`
if [ "$dockerCons" != "" ] ; then
    exit 0
fi
exit 1
