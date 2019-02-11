#! /bin/bash
. /etc/bashrc


#获取Shell当前执行的目录（路径）
BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

# 172.16.131.90  dev enp0s3 scope globa
echo NEBULA_VIP=$NEBULA_VIP

CMD=$1
shift
start(){
rm -rf /tmp/stop_keepalived
cat /etc/keepalived/header.conf  > /etc/keepalived/keepalived.conf 
if [ "$INSTALL_LVS" = "true" ] ; then
    LOCAL_HOST=`hostname`
    LOCAL_IP=$(ping $LOCAL_HOST -c 1 |grep "icmp_seq" |grep from|sed -e 's|.*(||' -e 's|).*||') 
    $APP_BASE/install/keepalived/lvs_config.sh $LOCAL_IP $LOCAL_HOST 2>&1
    if [ "$?" != "0" ] ; then
        echo "config lvs error"
        exit 1
    fi
    cat /etc/keepalived/lvs.conf  >> /etc/keepalived/keepalived.conf 
    ## 启动其它主机上的lvs配置  ka_master.sh 中启动
    #for HOST in ${CLUSTER_HOST_LIST//,/ } ; do
    #    ssh $HOST "$APP_BASE/install/lvs_realserver.sh start "
    #    ssh $HOST $APP_BASE/install/iptable_trans.sh  
    #done
fi

VIP_LINE=`cat /etc/keepalived/keepalived.conf |grep "scope globa"`
IF_NAME=`echo "$VIP_LINE"|awk '{print $3}'`
# vip mod
sed -i -e "s/.*$VIP_LINE/       $NEBULA_VIP dev $IF_NAME scope globa/" /etc/keepalived/keepalived.conf 
cat /etc/keepalived/keepalived.conf | grep "scope globa"

/usr/sbin/keepalived $@

}
 
stop(){
touch /tmp/stop_keepalived
sleep 1
if [ "$MAINPID" != "" ] ; then
/bin/kill -HUP $MAINPID
elif  [ "$#" -gt "0" ] ; then
/bin/kill $@
fi
int=0
while(( $int<=5 )) ;  do
    pids=$(ps -ef|grep /usr/sbin/keepalived|grep -v grep | awk '{print $2}')
    if [ "$pids" != "" ] ; then
        for pid in $pids ; do
            kill -HUP "$pid" 
        done
    else
        break
    fi
 sleep 0.5
 let "int++"
done

VIP_LINE=`cat /etc/keepalived/keepalived.conf |grep "scope globa"`
IF_NAME=`echo "$VIP_LINE"|awk '{print $3}'`
while [ true ];  do
    ipex=`ip a|grep $NEBULA_VIP |grep  $IF_NAME | wc -l`
    if [ "$ipex" = "0" ] ; then
        break
    else
        ip addr del $NEBULA_VIP dev $IF_NAME 
    fi
done
if [ "$INSTALL_LVS" = "true" ] ; then
    ipvsadm --clear
    $APP_BASE/install/lvs_realserver.sh start 
    $APP_BASE/install/iptable_trans.sh stop
fi
sleep 1
pids=$(ps -ef|grep /usr/sbin/keepalived|grep -v grep | awk '{print $2}')
if [ "$pids" != "" ] ; then
    for pid in $pids ; do
        kill  "$pid" 
    done
fi

}

if [ "$CMD" = "start" ]; then
  start " $@"
elif [ "$CMD" = "stop" ]; then
    stop " $@"
elif [ "$CMD" = "restart" ]; then
    stop " $@"
    sleep 3
    start " $@"
fi

exit 0
