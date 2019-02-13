#! /bin/bash
 
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ $# -lt 1 ] ; then 
  echo "usetag:haproxy_server.sh start|restart|stop "
  exit 1
fi

ORDER=$1
shift


DOCKER_CONNAME="dynamic-ha-haproxy-systemLB"
USE_LBSFLAGFILE="/etc/haproxy/useLbService"
useLbService=""
inited=""
if [ -f "$USE_LBSFLAGFILE" ] ; then
    useLbService=`cat /etc/haproxy/useLbService|grep useLbService=|sed -e "s|useLbService=||"`
    inited=`cat /etc/haproxy/useLbService|grep inited=|sed -e "s|inited=||"`
fi
testProcess(){
 kill -0 $1
 if [ "$?" = "0" ] ; then
    echo true
 else
   echo false
 fi
}

start(){
if [ "$useLbService" != "true" -o "$inited" != "true" ]; then
    /usr/sbin/haproxy-systemd-wrapper -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid $@  2>&1
else
    systemctl status docker > /dev/null 2>&1
    if [ "$?" != "0" ] ; then
        echo "docker service not started"
        exit 1 
    fi
    if [ ! -e "/etc/haproxy/systemLB" ] ; then
        echo "rebuild system haproxy "
        mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.` date "+%F,%H:%M:%S" `
        curl http://$HOSTNAME:64001/deploy/rebuildSystemHaproxy?force=true 
    fi
    
    docker ps -a|grep "$DOCKER_CONNAME"
    if [ "$?" != "0" ] ; then
        if [ -f "/etc/haproxy/systemLB/systemLB-run.sh" ] ; then
            /etc/haproxy/systemLB/systemLB-run.sh
        fi 
    fi
    
    docker start $DOCKER_CONNAME
    if [ "$?" != "0" ] ; then
        exit 1
    fi
    haPids=`docker top $DOCKER_CONNAME |grep -v PID|awk '{printf("%s " ,$2);}' `
    echo "haproxy pids:$haPids"
    while [ true ] ;  do
        systemctl status docker > /dev/null 2>&1
        if [ "$?" != "0" ] ; then
            echo "docker service not started"
            exit 1 
        fi
        docker ps |grep "$DOCKER_CONNAME" > /dev/null 2>&1
        if [ "$?" != "0" ] ; then
            exit 1
        fi
        sleep 1
        if [ ! -f "/etc/haproxy/haproxy.cfg" ] ; then
            scp /etc/haproxy/systemLB/haproxy.cfg /etc/haproxy/haproxy.cfg 
        fi
    done
fi
}
stop(){
    /bin/kill -USR2  $@
if [ "$useLbService" = "true" ]; then
    docker stop $DOCKER_CONNAME 
fi
}
restart(){
if [ "$useLbService" != "true" ]; then
    /bin/kill -USR2  $@
else
    docker restart $DOCKER_CONNAME 
fi
}

if [ "$ORDER" = "start" ]; then
  start $@
elif [ "$ORDER" = "stop" ]; then
  stop $@
elif [ "$ORDER" = "restart" ]; then
    restart $@
else
    echo "not support cmd"
    exit 1
fi

