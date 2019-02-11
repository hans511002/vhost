#! /bin/bash
#author:guowenting


export local_sh_dir="$KAFKA_HOME"
#读取kafka自定义的变量
KAFKA_HOME=$KAFKA_HOME
. ${KAFKA_HOME}/read_kafka_cfg.sh 

#进入本脚本所在目录
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`
cd $bin

SERVER_ARRAY=(`cat ${KAFKA_HOME}/conf/servers`)
COUNT=${#SERVER_ARRAY[@]}
echo "check kafka on nodes:  ${SERVER_ARRAY[*]}"


#检查zk中kafka 的节点文件是否完备,
#原理：若kafka所在的docker异常退出，则其在zookeeper中的文件会消失，所以检查zookeeper中的文件数即可

RUNEDHOST=
failed_RUNHOST=

ZK_DATA=$(${APP_BASE}/install/zkutil.sh "ls /brokers/ids")
echo  "kafka zookeeper data : ${ZK_DATA}"
echo ${ZK_DATA}
for ((i=0;i<$COUNT;i++))
do
    hostName="${SERVER_ARRAY[$i]}"
    echo "check $hostName status"
    nodeIp=`ping -c 1 $hostName |grep "from $hostName"|sed -e 's/.*(//' -e 's/).*//' -e 's/.*from//' -e 's/:.*//'`
    IP_TAIL=`echo $nodeIp|awk -F '.' '{print $4}'`
    str=`echo ${ZK_DATA}|grep ${IP_TAIL}`
    if [ "${str}" != "" ];then
       RUNEDHOST="$hostName $RUNEDHOST"
       echo "kafka ${SERVER_ARRAY[$i]}:$nodeIp exists in zookeeper"
    else
      failed_RUNHOST="$hostName $failed_RUNHOST"
       echo "error!:kafka ${SERVER_ARRAY[$i]}:$nodeIp not exists in zookeeper"
       
    fi
done

if [ "$failed_RUNHOST" != "" ] ; then
    exit 1
fi

#
#演播室用的消息队列：Sobey_PNS
#收录使用的：        MSV_NOTIFY
#MOS网关：           Sobey_SBSMQ, mos_res 
#CommonGateway：     Sobey_CGW
#MSV555:             MPCNotifyMQ
# sobeyHiveNotify     resourceIndex    indexFetchMessage
#云盘需要              KafkaNotificationServerTopic
#  CGW_NOTIFY_KAFK_MQ
#    hivenotifyforml
#    hivenotifyforweb
#    ingestnotifyformos
#

topics="test"

if [ "$RUNEDHOST" != "" ] ; then
    if [ "${RUNEDHOST//$HOSTNAME/}" != "$RUNEDHOST" ] ; then
        for topic in $topics ; do
            echo "create kafka topic $topic: docker exec -i kafka-$HOSTNAME  /kafka/bin/kafka-topics.sh --create --topic $topic --replication-factor $COUNT --partitions 1 --zookeeper $ZOOKEEPER_URL "
            docker exec -i kafka-$HOSTNAME  /kafka/bin/kafka-topics.sh --create --topic $topic --replication-factor $COUNT --partitions 1 --zookeeper $ZOOKEEPER_URL 
        done
    else
        runHost=`echo "$RUNEDHOST"|awk '{print $1}'`
        for topic in $topics ; do
            echo "create kafka topic $topic: ssh $runHost docker exec -i kafka-$HOSTNAME  /kafka/bin/kafka-topics.sh --create --topic $topic --replication-factor $COUNT --partitions 1 --zookeeper $ZOOKEEPER_URL "
            ssh $runHost docker exec -i kafka-$runHost  /kafka/bin/kafka-topics.sh --create --topic $topic --replication-factor $COUNT --partitions 1 --zookeeper $ZOOKEEPER_URL 
        done
    fi
fi

echo "kafka topic list:"
docker exec -i kafka-$HOSTNAME  /kafka/bin/kafka-topics.sh --list --zookeeper $ZOOKEEPER_URL


echo "kafka cluster is Normal."
exit 0

