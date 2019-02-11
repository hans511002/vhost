#!/usr/bin/env bash

# Set environment variables here.

# This script sets variables multiple times over the course of starting an hbase process,
# so try to keep things idempotent unless you want to take an even deeper look
# into the startup scripts (bin/hbase, etc.)

# The java implementation to use.  Java 1.6 required.
# export JAVA_HOME=/usr/java/jdk1.6.0/
. ~/.bash_profile

# Extra Java CLASSPATH elements.  Optional.
bin=`dirname $0`
bin=`cd "$bin"; pwd`

if [ "x$INSTALL_HOME" == "x" ] ; then
   export INSTALL_HOME=`cd "$bin/../"; pwd`
fi

export COLLECT_CLASSPATH=$INSTALL_HOME/conf

#for f in $INSTALL_HOME/lib/*.jar ; do
#    COLLECT_CLASSPATH=${COLLECT_CLASSPATH}:$f;
#done
export COLLECT_CLASSPATH
if [ "$COLLECT_PID_DIR" == "" ] ; then
   export COLLECT_PID_DIR=$INSTALL_HOME/logs
fi
if [ "$COLLECT_LOG_DIR" == "" ] ; then
   export COLLECT_PID_DIR=$INSTALL_HOME/logs
fi

paramas="$@"

openDebug=false

if [ "$COMMAND" = "master" -o "$COMMAND" = "deploy" ] ; then
    if [ "$paramas" != "${paramas/ -d /}" -o "${paramas:0-3:3}" = " -d" -o "$paramas" != "${paramas/ -debug /}" -o "${paramas:0-7:7}" = " -debug" ] ; then
        openDebug=true
    fi
else
    if [ "$paramas" != "${paramas/ -debug /}" -o "${paramas:0-7:7}" = " -debug" ] ; then
        openDebug=true
    fi
fi

if [ "$openDebug" = "true" ] ; then
    export DEBUG="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=8000"
    if [ "$DEBUG" != "" ] ; then
        ports=`ps -ef|grep "Xrunjdwp:transport=dt_socket,server=y,suspend=n,address="|grep -v grep|sed -e "s|.*suspend=n,address=||" -e "s|-XX:OnOutOfMemoryError.*||"`
        maxPort=7999
        for port in $ports ; do
            if [ "$port" -gt "$maxPort" ] ; then
               maxPort=$port
           fi
        done
        ((maxPort++))
        DEBUG="${DEBUG/8000/$maxPort}"
    fi
   # echo "DEBUG=$DEBUG"
fi
