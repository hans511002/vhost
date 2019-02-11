#! /bin/bash
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`
cd $bin

CMD=$@

zkParams=" -server $ZOOKEEPER_URL" 

HOSTINZK=$(cat $ZOOKEEPER_HOME/conf/servers)
if [ "${HOSTINZK//$HOSTNAME/}" != "$HOSTINZK" ] ; then
    zkParams=""
fi
tryTimes=0
while ((tryTimes < 5 )) ;  do
((tryTimes++))
CMD_RES=`$ZOOKEEPER_HOME/bin/zkCli.sh $zkParams 2>/dev/null <<EOF
$CMD

EOF
`
if [ "${CMD_RES//Node does not exist/}" != "$CMD_RES" ] ; then
    CMD_RES=""
    break
fi
if [ "${CMD_RES//WatchedEvent state:SyncConnected type:None path:null/}" = "$CMD_RES" ] ; then
    CMD_RES=""
fi

CMD_RES=${CMD_RES##*WATCHER::} 
CMD_RES=${CMD_RES##*type:None path:null}
if [ "$CMD_RES" != "" ] ; then
    break
fi
done
echo ${CMD_RES}
