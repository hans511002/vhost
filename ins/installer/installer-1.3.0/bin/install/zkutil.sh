#! /bin/bash

. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`
cd $bin


CMD="$@"
if [ "${zookeeper_hosts//$HOSTNAME/}" = "${zookeeper_hosts}" ] ; then
    zkHost=${zookeeper_hosts//,/ }
    zkHost=`echo $zkHost | awk '{print $1}' `
    SSHHOST="ssh $zkHost"
else
    SSHHOST="ssh $HOSTNAME"
fi

CMD_RES=`$SSHHOST cd $bin\;$ZOOKEEPER_HOME/bin/zkCli.sh -server $ZOOKEEPER_URL <<EOF
$CMD


EOF
`

#分割字符串 :   "WATCHER:: WatchedEvent state:SyncConnected type:None path:null"
#返回分割字符串后面的内容

RETURN_STR=`echo ${CMD_RES##*WATCHER::}`
RETURN_STR=`echo ${RETURN_STR##*type:None path:null}`

echo ${RETURN_STR}


